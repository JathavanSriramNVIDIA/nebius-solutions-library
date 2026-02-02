# OSMO SSO Setup with Google and Azure AD via Keycloak

This document describes the SSO (Single Sign-On) implementation for OSMO using Keycloak as an identity broker with Google and Azure AD as identity providers.

## Overview

The implementation enables users to authenticate to OSMO using their Google or Microsoft (Azure AD) accounts instead of local credentials. Keycloak acts as an identity broker that federates authentication to these external identity providers.

```
User → OSMO UI → Keycloak → Google OAuth2
                         → Azure AD (Microsoft)
```

## Prerequisites

### Google Cloud Console Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
2. Create OAuth 2.0 Client ID (Web application)
3. Note down:
   - **Client ID**: `xxxxxxxxx.apps.googleusercontent.com`
   - **Client Secret**: `GOCSPX-xxxxxxxxx`
4. Add authorized redirect URI (after Keycloak is deployed):
   - `http://<KEYCLOAK_URL>/realms/osmo/broker/google/endpoint`

### Azure Portal Credentials

1. Go to [Azure Portal](https://portal.azure.com/) → Azure Active Directory → App registrations
2. New registration → Name: "OSMO SSO"
3. Note down:
   - **Application (client) ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - **Directory (tenant) ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
4. Create client secret: Certificates & secrets → New client secret
   - **Client Secret**: `xxxxxxxxxxxxxxxxxxxxxxxxx`
5. Add redirect URI: Authentication → Add platform → Web
   - `http://<KEYCLOAK_URL>/realms/osmo/broker/microsoft/endpoint`

## Deployment

### Step 1: Set Environment Variables

```bash
# Google OAuth2 credentials
export GOOGLE_CLIENT_ID="your-google-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="GOCSPX-your-secret"

# Azure AD credentials
export AZURE_CLIENT_ID="your-azure-application-id"
export AZURE_CLIENT_SECRET="your-azure-client-secret"
export AZURE_TENANT_ID="your-tenant-id"  # or 'common' for multi-tenant
```

### Step 2: Deploy OSMO with Keycloak

```bash
cd applications/osmo/deploy/002-setup
DEPLOY_KEYCLOAK=true ./03-deploy-osmo-control-plane.sh
```

### Step 3: Update Redirect URIs

After deployment, get the Keycloak URL and update the redirect URIs in Google Cloud Console and Azure Portal:

**For port-forward access (development):**
```bash
kubectl port-forward -n osmo svc/keycloak 8081:80
# Keycloak URL: http://localhost:8081
```

**For LoadBalancer access (production):**
```bash
# Get the external IP
kubectl get svc osmo-proxy -n osmo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Keycloak URL: http://<EXTERNAL_IP>/realms/osmo
```

Update redirect URIs:
- **Google Console**: `http://<KEYCLOAK_URL>/realms/osmo/broker/google/endpoint`
- **Azure Portal**: `http://<KEYCLOAK_URL>/realms/osmo/broker/microsoft/endpoint`

## Files Changed

### 1. `applications/osmo/deploy/002-setup/nginx-proxy.yaml`

Added Keycloak upstream and routing for SSO redirect flows.

**Changes:**
```yaml
# Added upstream for Keycloak
upstream keycloak {
  server keycloak.osmo.svc.cluster.local:80;
}

# Added location blocks for Keycloak paths
location /auth/ {
  proxy_pass http://keycloak;
}

location /realms/ {
  proxy_pass http://keycloak;
}

location /admin/ {
  proxy_pass http://keycloak;
}

location /js/ {
  proxy_pass http://keycloak;
}

location /resources/ {
  proxy_pass http://keycloak;
}
```

### 2. `applications/osmo/deploy/001-iac/osmo-proxy.tf`

Same nginx configuration changes as above, keeping Terraform and standalone YAML in sync.

**Changes:**
- Added `keycloak` upstream server block
- Added location blocks for `/auth/`, `/realms/`, `/admin/`, `/js/`, `/resources/`

### 3. `applications/osmo/deploy/002-setup/03-deploy-osmo-control-plane.sh`

Added SSO configuration support.

**Changes:**

1. **Environment variable declarations** (lines 467-475):
```bash
# SSO Identity Provider Configuration (Google and Azure AD)
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"
AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}"
AZURE_TENANT_ID="${AZURE_TENANT_ID:-common}"
```

2. **Google Identity Provider configuration** in Keycloak setup job:
```bash
# Configure Google Identity Provider (if credentials provided)
if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/osmo/identity-provider/instances" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "alias": "google",
      "displayName": "Google",
      "providerId": "google",
      "enabled": true,
      "trustEmail": true,
      "config": {
        "clientId": "...",
        "clientSecret": "...",
        "defaultScope": "openid email profile",
        "syncMode": "IMPORT"
      }
    }'
fi
```

3. **Azure AD Identity Provider configuration** in Keycloak setup job:
```bash
# Configure Azure AD (Microsoft) Identity Provider (if credentials provided)
if [ -n "$AZURE_CLIENT_ID" ] && [ -n "$AZURE_CLIENT_SECRET" ]; then
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/osmo/identity-provider/instances" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "alias": "microsoft",
      "displayName": "Microsoft",
      "providerId": "microsoft",
      "enabled": true,
      "trustEmail": true,
      "config": {
        "clientId": "...",
        "clientSecret": "...",
        "tenant": "...",
        "defaultScope": "openid email profile",
        "syncMode": "IMPORT"
      }
    }'
fi
```

4. **Output messages** showing SSO status and configuration instructions.

## Architecture

### Authentication Flow

1. User accesses OSMO UI at `http://<OSMO_PROXY_IP>/`
2. User clicks "Login" and is redirected to Keycloak
3. Keycloak login page shows options: "Login with Google" or "Login with Microsoft"
4. User selects identity provider and authenticates
5. Identity provider redirects back to Keycloak with authorization code
6. Keycloak exchanges code for tokens and creates/links user account
7. User is redirected back to OSMO UI with session established

### Network Flow

```
External Traffic
       │
       ▼
┌──────────────────┐
│   LoadBalancer   │
│   (osmo-proxy)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│                    NGINX                          │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ /api/*      │  │ /realms/*   │  │ /*        │ │
│  │ osmo-service│  │ keycloak    │  │ osmo-ui   │ │
│  └─────────────┘  └─────────────┘  └───────────┘ │
└──────────────────────────────────────────────────┘
```

## Verification

1. Access OSMO UI: `http://<OSMO_PROXY_IP>/`
2. Click "Login"
3. Verify Google and Microsoft login options appear
4. Test authentication with each provider
5. Verify user is logged in (not as "guest")

## Troubleshooting

### Check Keycloak Logs
```bash
kubectl logs -n osmo -l app.kubernetes.io/name=keycloak --tail=100
```

### Check Identity Provider Configuration
```bash
# Port-forward to Keycloak
kubectl port-forward -n osmo svc/keycloak 8081:80

# Access admin console
open http://localhost:8081/admin

# Login: admin / <password from secret>
kubectl get secret keycloak-admin-secret -n osmo -o jsonpath='{.data.password}' | base64 -d
```

### Verify Redirect URIs
In Keycloak Admin Console:
1. Go to Identity Providers → Google/Microsoft
2. Copy the "Redirect URI" shown
3. Ensure this exact URI is configured in Google Cloud Console / Azure Portal

### Common Issues

1. **"Invalid redirect_uri" error**
   - The redirect URI in Google/Azure doesn't match Keycloak's expected URI
   - Copy exact URI from Keycloak Identity Provider settings

2. **"Login with Google/Microsoft" not showing**
   - Identity provider not configured (credentials not set during deployment)
   - Re-run deployment with environment variables set

3. **User created but can't access OSMO**
   - Check if user is created in Keycloak (Users section)
   - Verify user has appropriate roles assigned

## Security Considerations

- Use HTTPS in production (configure TLS on LoadBalancer or Ingress)
- Restrict `trustEmail` if email verification is required
- Consider configuring allowed domains for Google/Azure authentication
- Rotate client secrets periodically
- Use Kubernetes secrets management (e.g., External Secrets Operator) for credentials in production
