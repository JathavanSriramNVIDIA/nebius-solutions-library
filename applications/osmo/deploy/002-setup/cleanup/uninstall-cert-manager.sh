#!/bin/bash
# Uninstall cert-manager (deployed by 03c-deploy-cert-manager.sh)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/defaults.sh"

CM_NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager}"
TLS_SECRET_NAME="${OSMO_TLS_SECRET_NAME:-osmo-tls}"
INGRESS_NS="${INGRESS_NAMESPACE:-ingress-nginx}"
OSMO_NS="${OSMO_NAMESPACE:-osmo}"

log_info "Uninstalling cert-manager and related resources..."

# Delete Certificate resources
kubectl delete certificate osmo-tls-cert -n "${OSMO_NS}" --ignore-not-found 2>/dev/null || true
log_info "Certificate resource deleted"

# Delete ClusterIssuers
kubectl delete clusterissuer letsencrypt-prod --ignore-not-found 2>/dev/null || true
kubectl delete clusterissuer letsencrypt-staging --ignore-not-found 2>/dev/null || true
log_info "ClusterIssuers deleted"

# Delete TLS secrets
kubectl delete secret "${TLS_SECRET_NAME}" -n "${OSMO_NS}" --ignore-not-found 2>/dev/null || true
kubectl delete secret "${TLS_SECRET_NAME}" -n "${INGRESS_NS}" --ignore-not-found 2>/dev/null || true
log_info "TLS secrets deleted"

# Uninstall cert-manager Helm release
helm uninstall cert-manager -n "${CM_NAMESPACE}" 2>/dev/null || true
log_info "cert-manager Helm release uninstalled"

# Delete CRDs (cert-manager CRDs are not removed by helm uninstall)
kubectl delete crd \
    certificates.cert-manager.io \
    certificaterequests.cert-manager.io \
    challenges.acme.cert-manager.io \
    clusterissuers.cert-manager.io \
    issuers.cert-manager.io \
    orders.acme.cert-manager.io \
    --ignore-not-found 2>/dev/null || true
log_info "cert-manager CRDs deleted"

# Delete namespace
kubectl delete namespace "${CM_NAMESPACE}" --ignore-not-found --timeout=60s 2>/dev/null || true

log_success "cert-manager fully uninstalled"
