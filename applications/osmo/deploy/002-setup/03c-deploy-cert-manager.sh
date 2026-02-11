#!/bin/bash
#
# Deploy cert-manager with Let's Encrypt HTTP-01 challenge for automatic
# TLS certificate issuance and renewal.
#
# This is the AUTOMATED alternative to 03a (manual certbot). cert-manager
# runs in the cluster and handles certificate lifecycle automatically.
#
# Prerequisites:
#   - OSMO_INGRESS_HOSTNAME set to your domain (must have an A record
#     pointing to the NGINX Ingress LoadBalancer IP)
#   - LETSENCRYPT_EMAIL set to your email for Let's Encrypt registration
#   - kubectl and helm connected to the cluster
#   - 03-deploy-nginx-ingress.sh already run (LoadBalancer IP assigned)
#
# Run after 03-deploy-nginx-ingress.sh and before 04-deploy-osmo-control-plane.sh.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/defaults.sh"

echo ""
echo "========================================"
echo "  cert-manager Deployment"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
check_kubectl || exit 1
check_helm || exit 1

DOMAIN="${OSMO_INGRESS_HOSTNAME:-}"
EMAIL="${LETSENCRYPT_EMAIL:-}"
CM_NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager}"
ISSUER_NAME="${CLUSTER_ISSUER_NAME:-letsencrypt-prod}"
TLS_SECRET_NAME="${OSMO_TLS_SECRET_NAME:-osmo-tls}"
INGRESS_NS="${INGRESS_NAMESPACE:-ingress-nginx}"
OSMO_NS="${OSMO_NAMESPACE:-osmo}"

if [[ -z "$DOMAIN" ]]; then
    log_error "OSMO_INGRESS_HOSTNAME is not set."
    echo ""
    echo "Set your domain before running this script:"
    echo "  export OSMO_INGRESS_HOSTNAME=osmo.example.com"
    echo ""
    echo "IMPORTANT: Your domain's A record must point to the NGINX Ingress"
    echo "LoadBalancer IP for HTTP-01 challenge to work."
    echo ""
    echo "Get the LoadBalancer IP:"
    echo "  kubectl get svc -n ${INGRESS_NS} -l app.kubernetes.io/name=ingress-nginx \\"
    echo "    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'"
    echo ""
    exit 1
fi

if [[ -z "$EMAIL" ]]; then
    log_error "LETSENCRYPT_EMAIL is not set."
    echo ""
    echo "Set your email for Let's Encrypt registration:"
    echo "  export LETSENCRYPT_EMAIL=you@example.com"
    echo ""
    exit 1
fi

log_info "Domain:           ${DOMAIN}"
log_info "Email:            ${EMAIL}"
log_info "cert-manager ns:  ${CM_NAMESPACE}"
log_info "ClusterIssuer:    ${ISSUER_NAME}"
log_info "TLS secret name:  ${TLS_SECRET_NAME}"

# Verify LoadBalancer IP is assigned
LB_IP=$(kubectl get svc -n "${INGRESS_NS}" \
    -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -z "$LB_IP" ]]; then
    log_warning "Could not detect NGINX Ingress LoadBalancer IP."
    echo "  Ensure 03-deploy-nginx-ingress.sh was run and the LoadBalancer has an IP."
    echo "  HTTP-01 challenge requires the domain to resolve to this IP."
    echo ""
else
    log_success "NGINX Ingress LoadBalancer IP: ${LB_IP}"
    echo ""
    echo "IMPORTANT: Ensure your DNS has an A record:"
    echo "  ${DOMAIN} -> ${LB_IP}"
    echo ""
fi

# -----------------------------------------------------------------------------
# Add Helm repo and install cert-manager
# -----------------------------------------------------------------------------
log_info "Adding jetstack Helm repository..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

log_info "Creating namespace ${CM_NAMESPACE}..."
kubectl create namespace "${CM_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

log_info "Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace "${CM_NAMESPACE}" \
    --set crds.installCRDs=true \
    --set global.leaderElection.namespace="${CM_NAMESPACE}" \
    --wait --timeout 5m || {
    log_warning "Helm install returned non-zero; cert-manager may still be starting."
}

# Wait for cert-manager to be ready
log_info "Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=Ready pod \
    -l app.kubernetes.io/instance=cert-manager \
    -n "${CM_NAMESPACE}" --timeout=120s || {
    log_warning "cert-manager pods not fully ready yet. Continuing..."
}

log_success "cert-manager installed"

# -----------------------------------------------------------------------------
# Create ClusterIssuers
# -----------------------------------------------------------------------------
log_info "Creating Let's Encrypt ClusterIssuers..."

# Production issuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${ISSUER_NAME}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

log_success "ClusterIssuer '${ISSUER_NAME}' created (production)"

# Staging issuer (for testing without rate limits)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

log_success "ClusterIssuer 'letsencrypt-staging' created (for testing)"

# Wait for issuers to be ready
sleep 5
log_info "Checking ClusterIssuer status..."
kubectl get clusterissuer "${ISSUER_NAME}" -o jsonpath='{.status.conditions[0].message}' 2>/dev/null || true
echo ""

# -----------------------------------------------------------------------------
# Create Certificate resource
# -----------------------------------------------------------------------------
log_info "Creating Certificate resource for ${DOMAIN}..."

# Ensure the target namespace exists
kubectl create namespace "${OSMO_NS}" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: osmo-tls-cert
  namespace: ${OSMO_NS}
spec:
  secretName: ${TLS_SECRET_NAME}
  issuerRef:
    name: ${ISSUER_NAME}
    kind: ClusterIssuer
  dnsNames:
  - ${DOMAIN}
  duration: 2160h    # 90 days
  renewBefore: 720h  # Renew 30 days before expiry
EOF

log_success "Certificate resource created"

# Wait for certificate to be issued
log_info "Waiting for certificate to be issued (this may take 1-2 minutes)..."
echo "  cert-manager is performing HTTP-01 challenge against ${DOMAIN}..."
echo ""

cert_ready=false
for i in $(seq 1 36); do
    status=$(kubectl get certificate osmo-tls-cert -n "${OSMO_NS}" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [[ "$status" == "True" ]]; then
        cert_ready=true
        break
    fi
    # Show progress
    reason=$(kubectl get certificate osmo-tls-cert -n "${OSMO_NS}" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "Pending")
    echo "  Status: ${reason} ($i/36, waiting 5s...)"
    sleep 5
done

if [[ "$cert_ready" == "true" ]]; then
    log_success "Certificate issued successfully!"
    echo ""
    # Show certificate details
    kubectl get certificate osmo-tls-cert -n "${OSMO_NS}"
    echo ""
else
    log_error "Certificate was not issued within 3 minutes."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check that ${DOMAIN} resolves to the LoadBalancer IP (${LB_IP:-unknown})"
    echo "     nslookup ${DOMAIN}"
    echo ""
    echo "  2. Check certificate status:"
    echo "     kubectl describe certificate osmo-tls-cert -n ${OSMO_NS}"
    echo ""
    echo "  3. Check challenge status:"
    echo "     kubectl get challenges -n ${OSMO_NS}"
    echo "     kubectl describe challenges -n ${OSMO_NS}"
    echo ""
    echo "  4. Check cert-manager logs:"
    echo "     kubectl logs -n ${CM_NAMESPACE} -l app.kubernetes.io/name=cert-manager --tail=50"
    echo ""
    echo "  5. For testing, try the staging issuer first (no rate limits):"
    echo "     Edit the Certificate to use issuerRef.name: letsencrypt-staging"
    echo ""
    exit 1
fi

# Copy secret to ingress namespace if different
if [[ "$OSMO_NS" != "$INGRESS_NS" ]]; then
    log_info "Copying TLS secret to namespace '${INGRESS_NS}'..."
    kubectl get secret "${TLS_SECRET_NAME}" -n "${OSMO_NS}" -o yaml \
        | sed "s/namespace: ${OSMO_NS}/namespace: ${INGRESS_NS}/" \
        | kubectl apply -f - 2>/dev/null || log_warning "Could not copy secret to ${INGRESS_NS}"
fi

# -----------------------------------------------------------------------------
# Export variables for downstream scripts
# -----------------------------------------------------------------------------
export OSMO_TLS_ENABLED="true"
export OSMO_TLS_SECRET_NAME="${TLS_SECRET_NAME}"
export OSMO_TLS_MODE="cert-manager"

echo ""
echo "========================================"
log_success "cert-manager Deployment Complete"
echo "========================================"
echo ""
echo "Certificate will be automatically renewed by cert-manager."
echo ""
echo "Next steps:"
echo "  1. Ensure these variables are set before running further scripts:"
echo "     export OSMO_TLS_ENABLED=true"
echo "     export OSMO_INGRESS_HOSTNAME=${DOMAIN}"
echo ""
echo "  2. Run 04-deploy-osmo-control-plane.sh to deploy OSMO with TLS"
echo ""
echo "  3. Access OSMO at: https://${DOMAIN}"
echo ""
echo "Useful commands:"
echo "  Check certificate: kubectl get certificate osmo-tls-cert -n ${OSMO_NS}"
echo "  Check secret:      kubectl get secret ${TLS_SECRET_NAME} -n ${OSMO_NS}"
echo "  Check issuers:     kubectl get clusterissuer"
echo ""
