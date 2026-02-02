# =============================================================================
# Local Values
# =============================================================================

locals {
  # Resource naming
  name_prefix = "${var.project_name}-${var.environment}"

  # SSH key handling
  ssh_public_key = var.ssh_public_key.key != null ? var.ssh_public_key.key : (
    fileexists(var.ssh_public_key.path) ? file(var.ssh_public_key.path) : null
  )

  # Region-specific defaults
  region_defaults = {
    eu-north1 = {
      gpu_nodes_platform = "gpu-h100-sxm"
      gpu_nodes_preset   = "8gpu-128vcpu-1600gb"
      infiniband_fabric  = "fabric-3"
    }
    eu-west1 = {
      gpu_nodes_platform = "gpu-h200-sxm"
      gpu_nodes_preset   = "8gpu-128vcpu-1600gb"
      infiniband_fabric  = "fabric-5"
    }
    eu-north2 = {
      gpu_nodes_platform = "gpu-h200-sxm"
      gpu_nodes_preset   = "8gpu-128vcpu-1600gb"
      infiniband_fabric  = "eu-north2-a"
    }
    us-central1 = {
      gpu_nodes_platform = "gpu-h200-sxm"
      gpu_nodes_preset   = "8gpu-128vcpu-1600gb"
      infiniband_fabric  = "us-central1-a"
    }
  }

  # Available GPU platforms by region (for reference)
  # eu-north1:
  #   - gpu-h200-sxm (H200, 141GB VRAM) - high-end
  #   - gpu-h100-sxm (H100, 80GB VRAM) - high-end
  #   - gpu-l40s-a   (L40S Intel, 48GB VRAM) - cost-effective
  #   - gpu-l40s-d   (L40S AMD, 48GB VRAM) - cost-effective
  #
  # L40S presets: 1gpu-8vcpu-32gb, 2gpu-16vcpu-64gb (verify in console)
  # H100/H200 presets: 1gpu-16vcpu-200gb, 8gpu-128vcpu-1600gb

  # Current region config with overrides
  current_region = local.region_defaults[var.region]

  gpu_nodes_platform = coalesce(var.gpu_nodes_platform, local.current_region.gpu_nodes_platform)
  gpu_nodes_preset   = coalesce(var.gpu_nodes_preset, local.current_region.gpu_nodes_preset)
  infiniband_fabric  = coalesce(var.infiniband_fabric, local.current_region.infiniband_fabric)

  # Generate unique storage bucket name if not provided
  storage_bucket_name = var.storage_bucket_name != "" ? var.storage_bucket_name : "${local.name_prefix}-storage-${random_string.suffix.result}"

  # Common tags/labels
  common_labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false

  keepers = {
    project_id = var.parent_id
  }
}
