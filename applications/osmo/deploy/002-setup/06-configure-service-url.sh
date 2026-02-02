#!/bin/bash
#
# Configure OSMO Service URL
# Required for osmo-ctrl sidecar to communicate with OSMO service
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
source "${SCRIPT_DIR}/lib/common.sh"

echo ""
echo "========================================"
echo "  OSMO Service URL Configuration"
echo "========================================"
echo ""

# Check prerequisites
check_kubectl || exit 1

# -----------------------------------------------------------------------------
# Start port-forward
# -----------------------------------------------------------------------------
log_info "Starting port-forward to OSMO service..."

kubectl port-forward -n osmo svc/osmo-service 8080:80 &>/dev/null &
PORT_FORWARD_PID=$!

cleanup_port_forward() {
    if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
        wait $PORT_FORWARD_PID 2>/dev/null || true
    fi
}
trap cleanup_port_forward EXIT

# Wait for port-forward to be ready
log_info "Waiting for port-forward to be ready..."
max_wait=30
elapsed=0
while ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/api/version" 2>/dev/null | grep -q "200\|401\|403"; do
    sleep 1
    ((elapsed += 1))
    if [[ $elapsed -ge $max_wait ]]; then
        log_error "Port-forward failed to start within ${max_wait}s"
        exit 1
    fi
done
log_success "Port-forward ready"

# Login
log_info "Logging in to OSMO..."
if ! osmo login http://localhost:8080 --method dev --username admin 2>/dev/null; then
    log_error "Failed to login to OSMO"
    exit 1
fi
log_success "Logged in successfully"

# -----------------------------------------------------------------------------
# Check current service_base_url
# -----------------------------------------------------------------------------
log_info "Checking current service_base_url..."

CURRENT_URL=$(curl -s "http://localhost:8080/api/configs/service" 2>/dev/null | jq -r '.service_base_url // ""')
echo "Current service_base_url: '${CURRENT_URL}'"

if [[ -n "$CURRENT_URL" && "$CURRENT_URL" != "null" ]]; then
    log_success "service_base_url is already configured: ${CURRENT_URL}"
    echo ""
    echo "To reconfigure, delete the current value first or update manually."
    cleanup_port_forward
    trap - EXIT
    exit 0
fi

# -----------------------------------------------------------------------------
# Configure service_base_url
# -----------------------------------------------------------------------------
log_info "Configuring service_base_url..."

# The osmo-ctrl sidecar needs to connect to the OSMO service via the proxy
SERVICE_URL="http://osmo-proxy.osmo.svc.cluster.local:80"

cat > /tmp/service_url_fix.json << EOF
{
  "service_base_url": "${SERVICE_URL}"
}
EOF

if echo 'Configure service URL' | EDITOR='tee' osmo config update SERVICE --file /tmp/service_url_fix.json 2>/dev/null; then
    log_success "service_base_url configured"
else
    log_error "Failed to configure service_base_url"
    rm -f /tmp/service_url_fix.json
    exit 1
fi

rm -f /tmp/service_url_fix.json

# -----------------------------------------------------------------------------
# Verify Configuration
# -----------------------------------------------------------------------------
log_info "Verifying configuration..."

NEW_URL=$(curl -s "http://localhost:8080/api/configs/service" 2>/dev/null | jq -r '.service_base_url // ""')

if [[ "$NEW_URL" == "$SERVICE_URL" ]]; then
    log_success "service_base_url verified: ${NEW_URL}"
else
    log_error "Verification failed. Expected: ${SERVICE_URL}, Got: ${NEW_URL}"
    exit 1
fi

# Cleanup
cleanup_port_forward
trap - EXIT

echo ""
echo "========================================"
log_success "OSMO Service URL configuration complete!"
echo "========================================"
echo ""
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "This URL is used by the osmo-ctrl sidecar container to:"
echo "  - Stream workflow logs to the OSMO service"
echo "  - Report task status and completion"
echo "  - Fetch authentication tokens"
echo ""
