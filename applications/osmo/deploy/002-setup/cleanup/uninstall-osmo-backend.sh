#!/bin/bash
#
# Uninstall OSMO Backend
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../defaults.sh"

echo ""
echo "========================================"
echo "  Uninstalling OSMO Backend"
echo "========================================"
echo ""

log_warning "This will remove OSMO Backend services"
read_prompt_var "Continue? (y/N)" confirm ""
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    exit 0
fi

log_info "Removing OSMO Backend..."
kubectl delete deployment osmo-backend -n "${OSMO_NAMESPACE}" --ignore-not-found
kubectl delete service osmo-backend -n "${OSMO_NAMESPACE}" --ignore-not-found
kubectl delete service osmo-api -n "${OSMO_NAMESPACE}" --ignore-not-found

log_success "OSMO Backend uninstalled"
