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

# Paths (compatible with bash and zsh)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # zsh - use %x prompt expansion for script path
    export SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
else
    export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
export VALUES_DIR="${SCRIPT_DIR}/values"
export LIB_DIR="${SCRIPT_DIR}/lib"
