#!/bin/bash
#
# Renew TLS certificate obtained via certbot (03a-setup-tls-certificate.sh).
#
# This is an INTERACTIVE script. If the certificate needs renewal, certbot
# will ask you to create a new DNS TXT record.
#
# Run this before the 90-day Let's Encrypt certificate expiry.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/defaults.sh"

echo ""
echo "========================================"
echo "  TLS Certificate Renewal (Certbot)"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
check_kubectl || exit 1

if ! command -v certbot &>/dev/null; then
    log_error "certbot is not installed."
    exit 1
fi

DOMAIN="${OSMO_INGRESS_HOSTNAME:-}"
CERT_DIR="${OSMO_TLS_CERT_DIR:-$HOME/.osmo-certs}"
TLS_SECRET_NAME="${OSMO_TLS_SECRET_NAME:-osmo-tls}"
INGRESS_NS="${INGRESS_NAMESPACE:-ingress-nginx}"
OSMO_NS="${OSMO_NAMESPACE:-osmo}"

if [[ -z "$DOMAIN" ]]; then
    log_error "OSMO_INGRESS_HOSTNAME is not set."
    echo "  export OSMO_INGRESS_HOSTNAME=osmo.example.com"
    exit 1
fi

# Check current certificate expiry
CERT_PATH="${CERT_DIR}/live/${DOMAIN}/fullchain.pem"
if [[ -f "$CERT_PATH" ]]; then
    log_info "Current certificate details:"
    openssl x509 -in "${CERT_PATH}" -noout -subject -dates 2>/dev/null || true
    echo ""
else
    log_warning "No existing certificate found at ${CERT_PATH}"
    log_info "Run 03a-setup-tls-certificate.sh first to obtain a certificate."
    exit 1
fi

# -----------------------------------------------------------------------------
# Renew certificate
# -----------------------------------------------------------------------------
log_info "Starting certificate renewal..."
echo ""
echo "If the certificate needs renewal, certbot will ask you to create"
echo "a new DNS TXT record. Follow the same process as initial setup."
echo ""

certbot renew \
    --manual \
    --preferred-challenges dns \
    --config-dir "${CERT_DIR}" \
    --work-dir "${CERT_DIR}/work" \
    --logs-dir "${CERT_DIR}/logs" \
    --cert-name "${DOMAIN}" || {
    log_error "certbot renewal failed. Check the output above."
    exit 1
}

# Verify renewed files
KEY_PATH="${CERT_DIR}/live/${DOMAIN}/privkey.pem"
if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
    log_error "Certificate files not found after renewal."
    exit 1
fi

log_success "Certificate renewed successfully"
echo ""
log_info "Updated certificate details:"
openssl x509 -in "${CERT_PATH}" -noout -subject -dates 2>/dev/null || true

# -----------------------------------------------------------------------------
# Update Kubernetes TLS secret
# -----------------------------------------------------------------------------
echo ""
log_info "Updating Kubernetes TLS secret '${TLS_SECRET_NAME}'..."

kubectl create secret tls "${TLS_SECRET_NAME}" \
    --cert="${CERT_PATH}" \
    --key="${KEY_PATH}" \
    --namespace "${INGRESS_NS}" \
    --dry-run=client -o yaml | kubectl apply -f -

log_success "TLS secret updated in namespace '${INGRESS_NS}'"

# Update in osmo namespace if different
if [[ "$OSMO_NS" != "$INGRESS_NS" ]]; then
    kubectl create secret tls "${TLS_SECRET_NAME}" \
        --cert="${CERT_PATH}" \
        --key="${KEY_PATH}" \
        --namespace "${OSMO_NS}" \
        --dry-run=client -o yaml | kubectl apply -f -
    log_success "TLS secret updated in namespace '${OSMO_NS}'"
fi

# -----------------------------------------------------------------------------
# Trigger NGINX to reload the certificate
# -----------------------------------------------------------------------------
log_info "Restarting NGINX Ingress Controller to pick up new certificate..."

INGRESS_RELEASE="${INGRESS_RELEASE_NAME:-ingress-nginx}"
kubectl rollout restart deployment/${INGRESS_RELEASE}-controller \
    -n "${INGRESS_NS}" 2>/dev/null || {
    log_warning "Could not restart NGINX controller. You may need to restart it manually:"
    echo "  kubectl rollout restart deployment -n ${INGRESS_NS} -l app.kubernetes.io/name=ingress-nginx"
}

kubectl rollout status deployment/${INGRESS_RELEASE}-controller \
    -n "${INGRESS_NS}" --timeout=120s 2>/dev/null || true

echo ""
echo "========================================"
log_success "TLS Certificate Renewal Complete"
echo "========================================"
echo ""
echo "OSMO remains accessible at: https://${DOMAIN}"
echo ""
