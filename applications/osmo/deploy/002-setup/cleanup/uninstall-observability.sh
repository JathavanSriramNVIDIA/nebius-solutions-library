#!/bin/bash
#
# Uninstall Observability Stack
#

set -e

# Determine script directory (works in bash and zsh)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../defaults.sh"

echo ""
echo "========================================"
echo "  Uninstalling Observability Stack"
echo "========================================"
echo ""

log_warning "This will remove Prometheus, Grafana, and Loki"
printf "Continue? (y/N): "
read confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    exit 0
fi

log_info "Removing Promtail..."
helm uninstall promtail -n "${MONITORING_NAMESPACE}" 2>/dev/null || true

log_info "Removing Loki..."
helm uninstall loki -n "${MONITORING_NAMESPACE}" 2>/dev/null || true

log_info "Removing Prometheus stack..."
helm uninstall prometheus -n "${MONITORING_NAMESPACE}" 2>/dev/null || true

# Remove CRDs
log_info "Removing Prometheus CRDs..."
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com --ignore-not-found
kubectl delete crd alertmanagers.monitoring.coreos.com --ignore-not-found
kubectl delete crd podmonitors.monitoring.coreos.com --ignore-not-found
kubectl delete crd probes.monitoring.coreos.com --ignore-not-found
kubectl delete crd prometheuses.monitoring.coreos.com --ignore-not-found
kubectl delete crd prometheusrules.monitoring.coreos.com --ignore-not-found
kubectl delete crd servicemonitors.monitoring.coreos.com --ignore-not-found
kubectl delete crd thanosrulers.monitoring.coreos.com --ignore-not-found

log_info "Removing monitoring namespace..."
kubectl delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found

log_success "Observability stack uninstalled"
