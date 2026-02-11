#!/bin/bash
# Uninstall TLS certificate (created by 03a-setup-tls-certificate.sh)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/defaults.sh"

TLS_SECRET_NAME="${OSMO_TLS_SECRET_NAME:-osmo-tls}"
INGRESS_NS="${INGRESS_NAMESPACE:-ingress-nginx}"
OSMO_NS="${OSMO_NAMESPACE:-osmo}"
CERT_DIR="${OSMO_TLS_CERT_DIR:-$HOME/.osmo-certs}"

log_info "Removing TLS certificate resources..."

# Delete TLS secrets
kubectl delete secret "${TLS_SECRET_NAME}" -n "${INGRESS_NS}" --ignore-not-found 2>/dev/null || true
kubectl delete secret "${TLS_SECRET_NAME}" -n "${OSMO_NS}" --ignore-not-found 2>/dev/null || true
log_success "TLS secrets deleted"

# Optionally remove local certbot files
if [[ -d "$CERT_DIR" ]]; then
    echo ""
    echo "Local certbot certificate directory: ${CERT_DIR}"
    echo "To remove it manually, run:"
    echo "  rm -rf ${CERT_DIR}"
    echo ""
fi

log_success "TLS certificate resources uninstalled"
