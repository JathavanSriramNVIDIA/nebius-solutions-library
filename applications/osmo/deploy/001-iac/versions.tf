terraform {
  # Requires >= 1.10.0 for ephemeral resources (MysteryBox integration)
  # Requires >= 1.11.0 for write-only sensitive fields (PostgreSQL password)
  required_version = ">= 1.11.0"

  required_providers {
    nebius = {
      source = "terraform-provider.storage.eu-north1.nebius.cloud/nebius/nebius"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    units = {
      source  = "dstaroff/units"
      version = ">= 1.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}

provider "nebius" {
  domain = "api.eu.nebius.cloud:443"
}

provider "random" {}

provider "kubernetes" {
  host                   = module.k8s.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8s.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "nebius"
    args        = ["mk8s", "cluster", "get-credentials", "--id", module.k8s.cluster_id, "--external", "--token-only"]
  }
}
