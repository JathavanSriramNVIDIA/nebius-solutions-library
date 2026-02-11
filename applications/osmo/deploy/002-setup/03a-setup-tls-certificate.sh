#!/bin/bash
#
# Obtain a TLS certificate using certbot with manual DNS-01 challenge.
#
# This is an INTERACTIVE script. Certbot will pause and ask you to create
# a DNS TXT record at your DNS provider to prove domain ownership.
#
# Prerequisites:
#   - certbot installed (apt install certbot / brew install certbot / pip install certbot)
#   - OSMO_INGRESS_HOSTNAME set to your domain (e.g. osmo.example.com)
#   - LETSENCRYPT_EMAIL set to your email for Let's Encrypt registration
#   - kubectl connected to the cluster
#
# Run after 03-deploy-nginx-ingress.sh and before 04-deploy-osmo-control-plane.sh.
#
# The script creates a Kubernetes TLS secret named "osmo-tls" in the
# ingress-nginx namespace. This secret is used by NGINX Ingress for TLS termination.
#
# For renewal, run 03b-renew-tls-certificate.sh before the 90-day expiry.
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

# Check required variables
DOMAIN="${OSMO_INGRESS_HOSTNAME:-}"
EMAIL="${LETSENCRYPT_EMAIL:-}"

if [[ -z "$DOMAIN" ]]; then
    log_error "OSMO_INGRESS_HOSTNAME is not set."
    echo ""
    echo "Set your domain before running this script:"
    echo "  export OSMO_INGRESS_HOSTNAME=osmo.example.com"
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

CERT_DIR="${OSMO_TLS_CERT_DIR:-$HOME/.osmo-certs}"
TLS_SECRET_NAME="${OSMO_TLS_SECRET_NAME:-osmo-tls}"
INGRESS_NS="${INGRESS_NAMESPACE:-ingress-nginx}"

log_info "Domain:          ${DOMAIN}"
log_info "Email:           ${EMAIL}"
log_info "Cert directory:  ${CERT_DIR}"
log_info "TLS secret name: ${TLS_SECRET_NAME}"
log_info "Target namespace: ${INGRESS_NS}"

# -----------------------------------------------------------------------------
# Create cert directory
# -----------------------------------------------------------------------------
mkdir -p "${CERT_DIR}/work" "${CERT_DIR}/logs"

# -----------------------------------------------------------------------------
# Run certbot (interactive DNS-01 challenge)
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
echo "  Starting Let's Encrypt DNS-01 Challenge"
echo "========================================"
echo ""
echo "Certbot will ask you to create a DNS TXT record."
echo "When prompted:"
echo "  1. Log in to your DNS provider"
echo "  2. Create a TXT record for _acme-challenge.${DOMAIN}"
echo "  3. Wait for DNS propagation (1-5 minutes)"
echo "  4. Press Enter in this terminal to continue"
echo ""
log_info "Starting certbot..."

certbot certonly \
    --manual \
    --preferred-challenges dns \
    -d "${DOMAIN}" \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --config-dir "${CERT_DIR}" \
    --work-dir "${CERT_DIR}/work" \
    --logs-dir "${CERT_DIR}/logs" || {
    log_error "certbot failed. Check the output above for details."
    exit 1
}

# -----------------------------------------------------------------------------
# Verify certificate files
# -----------------------------------------------------------------------------
CERT_PATH="${CERT_DIR}/live/${DOMAIN}/fullchain.pem"
KEY_PATH="${CERT_DIR}/live/${DOMAIN}/privkey.pem"

if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
    log_error "Certificate files not found after certbot."
    echo "  Expected cert: ${CERT_PATH}"
    echo "  Expected key:  ${KEY_PATH}"
    echo ""
    echo "Check certbot logs: ${CERT_DIR}/logs/"
    exit 1
fi

log_success "Certificate obtained successfully"
echo ""
echo "Certificate files:"
echo "  Full chain: ${CERT_PATH}"
echo "  Private key: ${KEY_PATH}"

# Show certificate details
echo ""
log_info "Certificate details:"
openssl x509 -in "${CERT_PATH}" -noout -subject -issuer -dates 2>/dev/null || true

# -----------------------------------------------------------------------------
# Create Kubernetes TLS secret
# -----------------------------------------------------------------------------
echo ""
log_info "Creating Kubernetes TLS secret '${TLS_SECRET_NAME}' in namespace '${INGRESS_NS}'..."

kubectl create secret tls "${TLS_SECRET_NAME}" \
    --cert="${CERT_PATH}" \
    --key="${KEY_PATH}" \
    --namespace "${INGRESS_NS}" \
    --dry-run=client -o yaml | kubectl apply -f -

log_success "TLS secret '${TLS_SECRET_NAME}' created in namespace '${INGRESS_NS}'"

# Also create in osmo namespace (some ingress resources may reference it there)
OSMO_NS="${OSMO_NAMESPACE:-osmo}"
if [[ "$OSMO_NS" != "$INGRESS_NS" ]]; then
    log_info "Creating TLS secret in namespace '${OSMO_NS}'..."
    kubectl create namespace "${OSMO_NS}" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
    kubectl create secret tls "${TLS_SECRET_NAME}" \
        --cert="${CERT_PATH}" \
        --key="${KEY_PATH}" \
        --namespace "${OSMO_NS}" \
        --dry-run=client -o yaml | kubectl apply -f -
    log_success "TLS secret also created in namespace '${OSMO_NS}'"
fi

# -----------------------------------------------------------------------------
# Export variables for downstream scripts
# -----------------------------------------------------------------------------
export OSMO_TLS_ENABLED="true"
export OSMO_TLS_SECRET_NAME="${TLS_SECRET_NAME}"

echo ""
echo "========================================"
log_success "TLS Certificate Setup Complete"
echo "========================================"
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
echo "Certificate renewal:"
echo "  Certificates expire after 90 days. Run 03b-renew-tls-certificate.sh to renew."
echo "  Cert directory: ${CERT_DIR}"
echo ""
