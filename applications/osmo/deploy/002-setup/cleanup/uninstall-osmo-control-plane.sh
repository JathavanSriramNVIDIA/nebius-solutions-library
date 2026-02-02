#!/bin/bash
#
# Uninstall OSMO Control Plane
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
echo "  Uninstalling OSMO Control Plane"
echo "========================================"
echo ""

log_warning "This will remove OSMO Control Plane and all OSMO resources"
printf "Continue? (y/N): "
read confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    exit 0
fi

log_info "Removing OSMO Control Plane..."
kubectl delete deployment osmo-control-plane -n "${OSMO_NAMESPACE}" --ignore-not-found
kubectl delete service osmo-control-plane -n "${OSMO_NAMESPACE}" --ignore-not-found
kubectl delete secret osmo-database -n "${OSMO_NAMESPACE}" --ignore-not-found
kubectl delete secret osmo-storage -n "${OSMO_NAMESPACE}" --ignore-not-found

log_info "Removing OSMO namespace..."
kubectl delete namespace "${OSMO_NAMESPACE}" --ignore-not-found

log_success "OSMO Control Plane uninstalled"
