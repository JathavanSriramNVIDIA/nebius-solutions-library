#!/bin/bash
#
# Uninstall GPU Infrastructure
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
echo "  Uninstalling GPU Infrastructure"
echo "========================================"
echo ""

log_warning "This will remove GPU Operator, Network Operator, and KAI Scheduler"
printf "Continue? (y/N): "
read confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    exit 0
fi

log_info "Removing KAI Scheduler..."
helm uninstall kai-scheduler -n "${KAI_SCHEDULER_NAMESPACE}" 2>/dev/null || true
kubectl delete namespace "${KAI_SCHEDULER_NAMESPACE}" --ignore-not-found

log_info "Removing Network Operator..."
helm uninstall network-operator -n "${NETWORK_OPERATOR_NAMESPACE}" 2>/dev/null || true
kubectl delete namespace "${NETWORK_OPERATOR_NAMESPACE}" --ignore-not-found

log_info "Removing GPU Operator..."
helm uninstall gpu-operator -n "${GPU_OPERATOR_NAMESPACE}" 2>/dev/null || true

# Remove GPU Operator CRDs
log_info "Removing GPU Operator CRDs..."
kubectl delete crd clusterpolicies.nvidia.com --ignore-not-found
kubectl delete crd nvidiadrivers.nvidia.com --ignore-not-found

kubectl delete namespace "${GPU_OPERATOR_NAMESPACE}" --ignore-not-found

log_success "GPU infrastructure uninstalled"
