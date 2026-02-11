# =============================================================================
# Default Configuration for Setup Scripts
# =============================================================================

# Namespaces
export GPU_OPERATOR_NAMESPACE="gpu-operator"
export NETWORK_OPERATOR_NAMESPACE="network-operator"
export KAI_SCHEDULER_NAMESPACE="kai-scheduler"
export MONITORING_NAMESPACE="monitoring"
export OSMO_NAMESPACE="osmo"

# Chart versions (leave empty for latest)
export GPU_OPERATOR_VERSION=""
export NETWORK_OPERATOR_VERSION=""
export KAI_SCHEDULER_VERSION="v0.12.4"  # Check https://github.com/NVIDIA/KAI-Scheduler/releases
export PROMETHEUS_VERSION=""
export GRAFANA_VERSION=""
export LOKI_VERSION=""

# GPU Operator settings
export GPU_DRIVER_ENABLED="false"  # Use Nebius driver-full images
export TOOLKIT_ENABLED="true"
export DEVICE_PLUGIN_ENABLED="true"
export MIG_MANAGER_ENABLED="false"

# Network Operator (only needed for InfiniBand/GPU clusters)
export ENABLE_NETWORK_OPERATOR="false"  # Set to "true" if using InfiniBand

# Observability settings
export PROMETHEUS_RETENTION_DAYS="15"
export LOKI_RETENTION_DAYS="7"
export GRAFANA_ADMIN_PASSWORD=""  # Auto-generated if empty

# NGINX Ingress Controller (deployed by 03-deploy-nginx-ingress.sh)
# Namespace where the NGINX Ingress Controller is deployed.
export INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
# Hostname for Ingress rules (e.g. osmo.example.com). Leave empty to use the LoadBalancer IP directly.
export OSMO_INGRESS_HOSTNAME="${OSMO_INGRESS_HOSTNAME:-}"
# Override for the service_base_url used by osmo-ctrl. Auto-detected from the ingress LoadBalancer if empty.
export OSMO_INGRESS_BASE_URL="${OSMO_INGRESS_BASE_URL:-}"

# Paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VALUES_DIR="${SCRIPT_DIR}/values"
export LIB_DIR="${SCRIPT_DIR}/lib"
