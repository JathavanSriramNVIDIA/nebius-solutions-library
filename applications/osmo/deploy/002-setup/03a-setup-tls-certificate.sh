#!/bin/bash
#
# Obtain TLS certificates using certbot with manual DNS-01 challenge.
#
# This is an INTERACTIVE script that guides you through obtaining certificates
# for your OSMO deployment. It handles both the main domain and the Keycloak
# auth subdomain (if needed) in a single run.
#
# Prerequisites:
#   - certbot installed (apt install certbot / brew install certbot / pip install certbot)
#   - kubectl connected to the cluster
#
# Run after 03-deploy-nginx-ingress.sh and before 04-deploy-osmo-control-plane.sh.
#
# Two TLS secrets are created (as needed):
#   osmo-tls       -> main domain (OSMO service/router/UI ingresses)
#   osmo-tls-auth  -> auth subdomain (Keycloak ingress, only if Keycloak is enabled)
#
# For renewal, run 03b-renew-tls-certificate.sh before the 90-day expiry.
#
# Non-interactive mode: set OSMO_INGRESS_HOSTNAME and LETSENCRYPT_EMAIL as env
# vars to skip the prompts. Set DEPLOY_KEYCLOAK=true to also obtain the auth cert.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/defaults.sh"

echo ""
echo "========================================"
echo "  TLS Certificate Setup (Certbot)"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
check_kubectl || exit 1

# Check certbot
if ! command -v certbot &>/dev/null; then
    log_error "certbot is not installed."
    echo ""
    echo "Install certbot using one of these methods:"
    echo "  Ubuntu/Debian: sudo apt install certbot"
    echo "  macOS:         brew install certbot"
    echo "  pip:           pip install certbot"
    echo "  snap:          sudo snap install certbot --classic"
    echo ""
    exit 1
fi
log_success "certbot found: $(certbot --version 2>&1 | head -1)"

# -----------------------------------------------------------------------------
# Interactive configuration
# -----------------------------------------------------------------------------
CERT_DIR="${OSMO_TLS_CERT_DIR:-$HOME/.osmo-certs}"
INGRESS_NS="${INGRESS_NAMESPACE:-ingress-nginx}"
OSMO_NS="${OSMO_NAMESPACE:-osmo}"

# Prompt for main domain
MAIN_DOMAIN="${OSMO_INGRESS_HOSTNAME:-}"
if [[ -z "$MAIN_DOMAIN" ]]; then
    echo "Enter the main OSMO domain (e.g. osmo.example.com):"
    read -r -p "  Domain: " MAIN_DOMAIN
    echo ""
    if [[ -z "$MAIN_DOMAIN" ]]; then
        log_error "Domain is required."
        exit 1
    fi
fi

# Prompt for email
EMAIL="${LETSENCRYPT_EMAIL:-}"
if [[ -z "$EMAIL" ]]; then
    echo "Enter your email for Let's Encrypt registration:"
    read -r -p "  Email: " EMAIL
    echo ""
    if [[ -z "$EMAIL" ]]; then
        log_error "Email is required."
        exit 1
    fi
fi

# Ask about Keycloak
# In interactive mode (we prompted for domain or email), always show the prompt so the user
# is not surprised when Keycloak is skipped. Only use DEPLOY_KEYCLOAK when both were pre-set.
if [[ -z "${OSMO_INGRESS_HOSTNAME:-}" ]] || [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; then
    SETUP_KEYCLOAK=""
else
    SETUP_KEYCLOAK="${DEPLOY_KEYCLOAK:-false}"
fi
if [[ -z "$SETUP_KEYCLOAK" ]]; then
    echo "Will you enable Keycloak authentication?"
    echo "  This requires a separate TLS certificate for the auth subdomain"
    echo "  (e.g. auth-${MAIN_DOMAIN})."
    echo ""
    read -r -p "  Enable Keycloak? [y/N]: " KC_ANSWER
    echo ""
    if [[ "$KC_ANSWER" =~ ^[Yy] ]]; then
        SETUP_KEYCLOAK="true"
    else
        SETUP_KEYCLOAK="false"
    fi
fi

# Derive auth domain
AUTH_DOMAIN=""
if [[ "$SETUP_KEYCLOAK" == "true" ]]; then
    AUTH_DOMAIN="${KEYCLOAK_HOSTNAME:-auth-${MAIN_DOMAIN}}"
fi

# Build list of domains to process
# Each entry: "domain:secret_name"
DOMAINS_TO_PROCESS=()
DOMAINS_TO_PROCESS+=("${MAIN_DOMAIN}:osmo-tls")
if [[ -n "$AUTH_DOMAIN" ]]; then
    DOMAINS_TO_PROCESS+=("${AUTH_DOMAIN}:${KEYCLOAK_TLS_SECRET_NAME:-osmo-tls-auth}")
fi

# Show summary
echo "========================================"
echo "  Certificate Plan"
echo "========================================"
echo ""
echo "  Email:          ${EMAIL}"
echo "  Cert directory: ${CERT_DIR}"
echo ""
echo "  Certificates to obtain:"
for entry in "${DOMAINS_TO_PROCESS[@]}"; do
    d="${entry%%:*}"
    s="${entry##*:}"
    echo "    ${d}  ->  secret '${s}'"
done
echo ""
if [[ ${#DOMAINS_TO_PROCESS[@]} -gt 1 ]]; then
    echo "  Certbot will run once per domain. Each requires a separate DNS TXT record."
    echo ""
fi
read -r -p "  Press Enter to continue (or Ctrl-C to abort)..."
echo ""

# -----------------------------------------------------------------------------
# Helper function: obtain cert and create secret for one domain
# -----------------------------------------------------------------------------
obtain_cert_and_create_secret() {
    local domain="$1"
    local secret_name="$2"

    echo ""
    echo "========================================"
    echo "  Certificate: ${domain}"
    echo "  Secret:      ${secret_name}"
    echo "========================================"
    echo ""

    # Create cert directory
    mkdir -p "${CERT_DIR}/work" "${CERT_DIR}/logs"

    # Run certbot
    echo "Certbot will ask you to create a DNS TXT record."
    echo "When prompted:"
    echo "  1. Log in to your DNS provider"
    echo "  2. Create a TXT record for _acme-challenge.${domain}"
    echo "  3. Wait for DNS propagation (1-5 minutes)"
    echo "  4. Press Enter in this terminal to continue"
    echo ""
    log_info "Starting certbot for ${domain}..."

    certbot certonly \
        --manual \
        --preferred-challenges dns \
        -d "${domain}" \
        --email "${EMAIL}" \
        --agree-tos \
        --no-eff-email \
        --config-dir "${CERT_DIR}" \
        --work-dir "${CERT_DIR}/work" \
        --logs-dir "${CERT_DIR}/logs" || {
        log_error "certbot failed for ${domain}. Check the output above."
        return 1
    }

    # Verify certificate files
    local cert_path="${CERT_DIR}/live/${domain}/fullchain.pem"
    local key_path="${CERT_DIR}/live/${domain}/privkey.pem"

    if [[ ! -f "$cert_path" || ! -f "$key_path" ]]; then
        log_error "Certificate files not found for ${domain}."
        echo "  Expected cert: ${cert_path}"
        echo "  Expected key:  ${key_path}"
        return 1
    fi

    log_success "Certificate obtained for ${domain}"
    echo ""
    echo "  Full chain: ${cert_path}"
    echo "  Private key: ${key_path}"

    # Show certificate details
    echo ""
    log_info "Certificate details:"
    openssl x509 -in "${cert_path}" -noout -subject -issuer -dates 2>/dev/null || true

    # Create Kubernetes TLS secrets
    echo ""
    log_info "Creating Kubernetes TLS secret '${secret_name}' in namespace '${INGRESS_NS}'..."
    kubectl create secret tls "${secret_name}" \
        --cert="${cert_path}" \
        --key="${key_path}" \
        --namespace "${INGRESS_NS}" \
        --dry-run=client -o yaml | kubectl apply -f -
    log_success "TLS secret '${secret_name}' created in namespace '${INGRESS_NS}'"

    if [[ "$OSMO_NS" != "$INGRESS_NS" ]]; then
        log_info "Creating TLS secret in namespace '${OSMO_NS}'..."
        kubectl create namespace "${OSMO_NS}" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
        kubectl create secret tls "${secret_name}" \
            --cert="${cert_path}" \
            --key="${key_path}" \
            --namespace "${OSMO_NS}" \
            --dry-run=client -o yaml | kubectl apply -f -
        log_success "TLS secret also created in namespace '${OSMO_NS}'"
    fi

    echo ""
    log_success "Done: ${domain} -> secret '${secret_name}'"
}

# -----------------------------------------------------------------------------
# Process each domain
# -----------------------------------------------------------------------------
FAILED=()
for entry in "${DOMAINS_TO_PROCESS[@]}"; do
    domain="${entry%%:*}"
    secret_name="${entry##*:}"
    if ! obtain_cert_and_create_secret "$domain" "$secret_name"; then
        FAILED+=("$domain")
    fi
done

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
if [[ ${#FAILED[@]} -gt 0 ]]; then
    log_warning "TLS Certificate Setup Partially Complete"
    echo "========================================"
    echo ""
    echo "  Failed domains:"
    for d in "${FAILED[@]}"; do
        echo "    - ${d}"
    done
    echo ""
    echo "  Fix the issues above and re-run this script."
else
    log_success "TLS Certificate Setup Complete"
    echo "========================================"
fi
echo ""
echo "  Secrets created:"
for entry in "${DOMAINS_TO_PROCESS[@]}"; do
    d="${entry%%:*}"
    s="${entry##*:}"
    if [[ ! " ${FAILED[*]} " =~ " ${d} " ]]; then
        echo "    ${d}  ->  ${s}"
    fi
done
echo ""
echo "Next steps:"
echo "  1. Set these variables before running further scripts:"
echo ""
echo "     export OSMO_TLS_ENABLED=true"
echo "     export OSMO_INGRESS_HOSTNAME=${MAIN_DOMAIN}"
if [[ "$SETUP_KEYCLOAK" == "true" ]]; then
    echo "     export DEPLOY_KEYCLOAK=true"
    echo "     export KEYCLOAK_HOSTNAME=${AUTH_DOMAIN}"
fi
echo ""
echo "  2. Run 04-deploy-osmo-control-plane.sh to deploy OSMO with TLS"
echo ""
echo "  3. Access OSMO at: https://${MAIN_DOMAIN}"
echo ""
echo "Certificate renewal:"
echo "  Certificates expire after 90 days. Run 03b-renew-tls-certificate.sh to renew."
echo "  Cert directory: ${CERT_DIR}"
echo ""
