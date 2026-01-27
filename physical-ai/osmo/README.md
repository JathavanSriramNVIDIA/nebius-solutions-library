# Physical AI Workflow Orchestration on Nebius Cloud

Deploy [NVIDIA OSMO](https://nvidia.github.io/OSMO/main/user_guide/index.html) on [Nebius AI Cloud](https://nebius.com/ai-cloud) in minutes. Run simulation, training, and edge workflows on the wide variety of Nebius GPU instances—write once in YAML, run anywhere.


## Known Gaps and TODOs

| Gap | Current Workaround | Status |
|-----|-------------------|--------|
| No managed Redis service | Deploy Redis in-cluster via Helm | Workaround in place |
| MysteryBox lacks K8s CSI integration | Scripts retrieve secrets and create K8s secrets manually | Workaround in place |
| No External DNS service | Manual DNS configuration required | Not addressed |
| No managed SSL/TLS service | Manual certificate management | Not addressed |
| No public Load Balancer (ALB/NLB) | Use port-forwarding or WireGuard VPN for access | Workaround in place |
| IDP integration for Nebius | Using OSMO dev auth mode; Keycloak available but not integrated | TBD |
| Nebius Observability Stack integration | Using self-deployed Prometheus/Grafana/Loki | TODO |
| Single cluster for Control Plane + Backend | Using 1 MK8s cluster for both; production separation TBD | Discuss with Nebius |

## What You Get

Production-ready infrastructure-as-code (Terraform) and setup scripts for:
- **Managed Kubernetes (MK8s)** cluster with GPU and CPU node groups
- **GPU Infrastructure** including GPU Operator, Network Operator, and KAI Scheduler
- **Observability Stack** with Prometheus, Grafana, and Loki
- **OSMO Control Plane and Backend** for workflow orchestration
- **Supporting Services** including PostgreSQL, Object Storage, Filestore, and Container Registry
- **Secure Access** via WireGuard VPN (optional)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Nebius AI Cloud                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         Nebius VPC Network                               │    │
│  │                                                                          │    │
│  │  ┌─────────────┐  ┌────────────────────────────────────────────────┐    │    │
│  │  │  WireGuard  │  │        Nebius Managed Kubernetes (MK8s)        │    │    │
│  │  │    VPN      │  │                                                │    │    │
│  │  │ (Optional)  │  │  ┌────────────────────────────────────────┐   │    │    │
│  │  └──────┬──────┘  │  │           OSMO Namespace                │   │    │    │
│  │         │         │  │  ┌──────────┐ ┌────────┐ ┌──────────┐  │   │    │    │
│  │         │         │  │  │  osmo-   │ │ osmo-  │ │  osmo-   │  │   │    │    │
│  │         │         │  │  │ service  │ │ logger │ │  agent   │  │   │    │    │
│  │         │         │  │  └────┬─────┘ └───┬────┘ └────┬─────┘  │   │    │    │
│  │         │         │  │       └────────────┼──────────┘        │   │    │    │
│  │         │         │  │              ┌─────┴─────┐              │   │    │    │
│  │         │         │  │              │osmo-proxy │              │   │    │    │
│  │         │         │  │              │  (nginx)  │              │   │    │    │
│  │         │         │  │              └─────┬─────┘              │   │    │    │
│  │         │         │  │                    │                    │   │    │    │
│  │         │         │  │  ┌─────────┐  ┌────┴────┐  ┌─────────┐ │   │    │    │
│  │         │         │  │  │ osmo-ui │  │osmo-ctrl│  │osmo-    │ │   │    │    │
│  │         │         │  │  │ (Web UI)│  │(sidecar)│  │backend  │ │   │    │    │
│  │         │         │  │  └─────────┘  └─────────┘  └─────────┘ │   │    │    │
│  │         │         │  └────────────────────────────────────────┘   │    │    │
│  │         │         │                                                │    │    │
│  │         └─────────┼───► ┌──────────────┐  ┌───────────────────┐   │    │    │
│  │                   │     │  CPU Nodes   │  │    GPU Nodes      │   │    │    │
│  │                   │     │  (cpu-d3)    │  │  (L40S/H100/H200) │   │    │    │
│  │                   │     │  System pods │  │  Workflow pods    │   │    │    │
│  │                   │     └──────────────┘  └───────────────────┘   │    │    │
│  │                   │                                                │    │    │
│  │                   │  ┌────────────────────────────────────────┐   │    │    │
│  │                   │  │         Infrastructure Stack           │   │    │    │
│  │                   │  │  GPU Operator, Network Operator, Cilium│   │    │    │
│  │                   │  │  Prometheus, Grafana, Loki             │   │    │    │
│  │                   │  └────────────────────────────────────────┘   │    │    │
│  │                   └────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐        │
│  │   Managed     │ │    Object     │ │    Shared     │ │   Container   │        │
│  │  PostgreSQL   │ │   Storage     │ │  Filesystems  │ │   Registry    │        │
│  │  (OSMO DB)    │ │ (Workflow     │ │  (Datasets)   │ │   (Images)    │        │
│  │               │ │  logs/data)   │ │               │ │               │        │
│  └───────────────┘ └───────────────┘ └───────────────┘ └───────────────┘        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Nebius Services Used:**

| Service | Purpose |
|---------|---------|
| MK8s | Managed Kubernetes with CPU and GPU node groups |
| Managed PostgreSQL | Database for OSMO state and metadata |
| Object Storage | S3-compatible storage for workflow logs and artifacts |
| Shared Filesystems | NFS storage for datasets across nodes |
| Compute | VMs for WireGuard VPN (optional) |
| VPC | Private networking with subnet isolation |
| IAM | Service accounts and access keys |
| MysteryBox | Secrets management for credentials |
| Container Registry | Docker image storage for custom workflow images |

## Prerequisites

Before deploying, ensure you have access to Nebius AI Cloud and the required command-line tools installed. The deployment uses Terraform for infrastructure provisioning and Helm/kubectl for Kubernetes configuration.

- [**Nebius Account**](https://console.eu.nebius.com/) with appropriate permissions (see [Required Permissions](#required-permissions))
- [**Nebius CLI**](https://docs.nebius.com/cli/install) installed and authenticated
- [**Terraform**](https://developer.hashicorp.com/terraform/install) >= 1.5.0 for infrastructure-as-code
- [**kubectl**](https://kubernetes.io/docs/tasks/tools/) >= 1.28 for Kubernetes cluster management (should match cluster version ±1 minor)
- [**Helm**](https://helm.sh/docs/intro/install/) >= 3.0 for deploying OSMO charts
- **SSH key pair** for node access (generate with `ssh-keygen` if needed)

## Quick Start

> **Important:** Complete all steps in the **same terminal session**. The setup scripts export environment variables that must persist across steps.

Please run this from a Linux Shell/Ubuntu/WSL.

### 1. Install Required Tools

```bash
cd deploy/000-prerequisites
./install-tools.sh        # Installs: Terraform, kubectl, Helm, Nebius CLI
./install-tools.sh --check  # Verify without installing
```

Supports Linux, WSL, and macOS. See [prerequisites README](deploy/000-prerequisites/README.md) for manual installation.

### 2. Configure Nebius Environment

> **Note:** If not authenticated, run `nebius profile create` first and follow the authentication flow.

```bash
source ./nebius-env-init.sh
```

This interactive script:
1. **Checks Nebius CLI** - Verifies installation and adds to PATH if needed
2. **Checks authentication** - If not authenticated, provides instructions to run `nebius profile create`
3. **Lists tenants** - Auto-detects if you have only one tenant
4. **Configures project** - Select existing project, create new one, or list available projects
5. **Sets region** - Choose between `eu-north1` (Finland) or `eu-west1` (Paris)
6. **Exports environment variables** - Sets `NEBIUS_*` and `TF_VAR_*` variables for Terraform

### 3. Initialize Secrets (REQUIRED)

```bash
source ./secrets-init.sh
```

> **Important:** This step is **REQUIRED** before running Terraform. If you skip it, `terraform apply` will fail with a clear error message.

This generates secure credentials and stores them in [Nebius MysteryBox](https://docs.nebius.com/mysterybox):
- **PostgreSQL password** - Used by Managed PostgreSQL and OSMO
- **MEK (Master Encryption Key)** - Used by OSMO for data encryption

The script exports `TF_VAR_*` environment variables that Terraform and setup scripts use to retrieve these secrets securely, keeping them out of Terraform state.

### 4. Deploy Infrastructure

Provision all Nebius cloud resources using Terraform: VPC network, Managed Kubernetes cluster, GPU/CPU node groups, PostgreSQL database, Object Storage, and optionally WireGuard VPN.

```bash
cd ../001-iac

# Recommended: Cost-optimized for development (see Appendix A)
cp terraform.tfvars.cost-optimized.example terraform.tfvars

# Edit terraform.tfvars if needed
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

> **Note:** If you get an error about missing `postgresql_mysterybox_secret_id`, go back to step 3 and run `source ./secrets-init.sh`.

See [Terraform README](deploy/001-iac/README.md) for configuration options, and [Appendix A](#appendix-a-terraform-configuration-presets) for preset comparisons.

### 5. Configure Kubernetes

1. Get Kubernetes credentials:
   ```bash
   nebius mk8s cluster get-credentials --id <cluster-id> --external
   ```

2. Verify cluster access:
   ```bash
   kubectl get nodes
   ```

3. Deploy GPU infrastructure and observability:
   ```bash
   cd ../002-setup
   ./01-deploy-gpu-infrastructure.sh
   ./02-deploy-observability.sh
   ```
   
   This installs:
   - NVIDIA GPU Operator and Network Operator
   - KAI Scheduler for GPU workload scheduling
   - Prometheus, Grafana, and Loki for monitoring

4. Deploy OSMO control plane:
   ```bash
   ./03-deploy-osmo-control-plane.sh
   ```
   
   This deploys the core OSMO services:
   - Creates `osmo` namespace and PostgreSQL/MEK secrets
   - Initializes databases on Nebius Managed PostgreSQL
   - Deploys Redis, Keycloak, and OSMO services (API, agent, worker, logger)
   - Sets up nginx proxy for routing
   
   > **Note:** The script automatically retrieves PostgreSQL password and MEK from MysteryBox if you ran `secrets-init.sh` earlier.

5. Deploy OSMO backend operator:
   ```bash
   ./04-deploy-osmo-backend.sh
   ```
   
   The script automatically:
   - Starts a port-forward to OSMO service
   - Logs in using dev method (since Keycloak auth is disabled)
   - Creates a service token for the backend operator
   - Deploys the backend operator
   - Cleans up the port-forward
   
   This deploys the backend operator that manages GPU workloads:
   - Connects to OSMO control plane via `osmo-agent`
   - Configures resource pools for GPU nodes
   - Enables workflow execution on the Kubernetes cluster
   
   > **Manual alternative:** If you prefer to create the token manually, set `OSMO_SERVICE_TOKEN` environment variable before running the script.

6. Verify backend deployment:
   
   To verify the backend is registered with OSMO, start a port-forward and check:
   ```bash
   # Terminal 1: Start port-forward (keep running)
   kubectl port-forward -n osmo svc/osmo-service 8080:80
   
   # Terminal 2: Verify backend registration
   osmo config show BACKEND default
   ```
   
   You should see the backend configuration with status `ONLINE`.

7. Configure OSMO storage:
   ```bash
   ./05-configure-storage.sh
   ```
   
   The script automatically:
   - Retrieves storage bucket details from Terraform
   - Starts port-forward and logs in to OSMO
   - Configures OSMO to use Nebius Object Storage for workflow artifacts
   - Verifies the configuration
   
   > **Note:** The `osmo-storage` secret (with S3 credentials) was created automatically by `03-deploy-osmo-control-plane.sh`.

8. Access OSMO (port-forwarding):
   
   Since the cluster uses private networking, use port-forwarding to access OSMO services:
   
   ```bash
   # Terminal 1: Forward OSMO API (required for CLI commands)
   kubectl port-forward -n osmo svc/osmo-service 8080:80
   
   # Terminal 2: Forward OSMO Web UI
   kubectl port-forward -n osmo svc/osmo-ui 8081:80
   ```
   
   Access points:
   - **OSMO API**: http://localhost:8080 (for CLI and API calls)
   - **OSMO Web UI**: http://localhost:8081 (browser-based dashboard)
   
   Login to OSMO CLI (required before running commands):
   ```bash
   osmo login http://localhost:8080 --method dev --username admin
   ```

9. Configure service URL (required for workflows):
   ```bash
   ./06-configure-service-url.sh
   ```
   
   The script configures `service_base_url` which is required for:
   - The `osmo-ctrl` sidecar to stream workflow logs
   - Task status reporting and completion tracking
   - Authentication token refresh during workflow execution
   
   > **Important:** Without this configuration, workflows will get stuck with `FETCH_FAILURE` errors.

10. Configure pool for GPU workloads:
   
   The default pool needs GPU platform configuration to run GPU workflows. This creates a pod template with the correct node selector and tolerations for GPU nodes:
   
   ```bash
   ./07-configure-gpu-platform.sh
   ```
   
   The script:
   - Creates a `gpu_tolerations` pod template with `nvidia.com/gpu.present: true` node selector
   - Updates the GPU platform to reference this pod template
   - Verifies GPU nodes are visible in OSMO
   
   You can verify the configuration:
   ```bash
   osmo config show POOL default
   osmo config show POD_TEMPLATE gpu_tolerations
   ```

11. Set up port-forwarding for OSMO access:
   
   Before using the OSMO CLI or Web UI, set up port-forwarding to the OSMO services:
   
   ```bash
   # Terminal 1: Port-forward to OSMO API (required for CLI and API access)
   kubectl port-forward -n osmo svc/osmo-service 8080:80
   
   # Terminal 2: Port-forward to OSMO Web UI (optional, for browser access)
   kubectl port-forward -n osmo svc/osmo-ui 8081:80
   ```
   
   Then configure the OSMO CLI to use the forwarded port:
   ```bash
   osmo profile set endpoint http://localhost:8080
   ```
   
   Access points:
   - **OSMO API**: http://localhost:8080
   - **OSMO Web UI**: http://localhost:8081

12. Run a test workflow (optional):
   
   Verify the complete setup by running a test workflow from the `workflows/osmo/` directory:
   
   ```bash
   # Set the default pool (required before submitting workflows)
   osmo profile set pool default
   
   # Submit the hello world workflow (requires GPU)
   osmo workflow submit ../../workflows/osmo/hello_nebius.yaml
   
   # Or specify the pool explicitly
   osmo workflow submit ../../workflows/osmo/hello_nebius.yaml --pool default
   
   # Check workflow status
   osmo workflow list
   osmo workflow query <workflow-id>
   
   # View workflow logs (CLI - recommended when using port-forwarding)
   osmo workflow query <workflow-id> --logs
   ```
   
   > **Note:** When using port-forwarding, the Web UI cannot display workflow logs (it tries to resolve internal Kubernetes DNS). Use the CLI commands above or `kubectl logs` instead.
   
   Available test workflows in `workflows/osmo/`:
   - `hello_nebius.yaml` - Simple GPU hello world
   - `gpu_test.yaml` - GPU validation test



## Configuration Tiers

| Tier | GPU Type | GPU Nodes | Security | Est. Cost/6h |
|------|----------|-----------|----------|--------------|
| **Cost-Optimized Secure** (recommended) | 1x L40S | 1 | WireGuard VPN | **~$15-25** |
| **Cost-Optimized** | 1x L40S | 1 | Public endpoints | ~$10-15 |
| **Standard** | 1x H100 | 1 | Public endpoints | ~$30-40 |
| **Production** | 8x H200 | 4+ | WireGuard VPN | ~$1000+ |

**Recommended:** Use `terraform.tfvars.cost-optimized-secure.example` for development.

See `deploy/001-iac/terraform.tfvars.*.example` files for all configuration options.

## GPU Options

| Platform | Preset | GPUs | VRAM | vCPUs | RAM | InfiniBand |
|----------|--------|------|------|-------|-----|------------|
| `gpu-l40s-a` | `1gpu-8vcpu-32gb` | 1 | 48GB | 8 | 32GB | No |
| `gpu-l40s-d` | `1gpu-8vcpu-32gb` | 1 | 48GB | 8 | 32GB | No |
| `gpu-h100-sxm` | `1gpu-16vcpu-200gb` | 1 | 80GB | 16 | 200GB | No |
| `gpu-h100-sxm` | `8gpu-128vcpu-1600gb` | 8 | 640GB | 128 | 1600GB | Yes |
| `gpu-h200-sxm` | `1gpu-16vcpu-200gb` | 1 | 141GB | 16 | 200GB | No |
| `gpu-h200-sxm` | `8gpu-128vcpu-1600gb` | 8 | 1128GB | 128 | 1600GB | Yes |

**Recommendation:** Use `gpu-l40s-a` for development/testing (cheapest option).

## Required Permissions

This deployment uses the [Nebius Terraform Provider](https://docs.nebius.com/terraform-provider/quickstart) to provision cloud resources. Your Nebius account needs the following IAM roles to create and manage the required infrastructure.

### Minimum Required Roles
| Role | Purpose |
|------|---------|
| `compute.admin` | VMs, disks, shared filesystems, GPU clusters |
| `vpc.admin` | VPC networks and subnets |
| `mk8s.admin` | Managed Kubernetes clusters and node groups |
| `storage.admin` | Object Storage buckets |
| `mdb.admin` | Managed PostgreSQL clusters |
| `iam.serviceAccounts.admin` | Service accounts and access keys |
| `container-registry.admin` | Container registries |

### For WireGuard VPN (Optional)
| Role | Purpose |
|------|---------|
| `vpc.publicIpAllocations.admin` | Allocate public IPs for VPN endpoint |

For more information, see [Nebius IAM Roles](https://docs.nebius.com/iam/authorization/roles) and the [Terraform Provider Quickstart](https://docs.nebius.com/terraform-provider/quickstart).

## Security Options

### Option A: WireGuard VPN (Recommended for Production)

Enable private-only access with WireGuard VPN:

```hcl
# In terraform.tfvars
enable_wireguard        = true
enable_public_endpoint  = false
```

After deployment:
```bash
cd deploy/000-prerequisites
./wireguard-client-setup.sh
```

### Option B: Public Endpoints

For development/testing with public access:

```hcl
# In terraform.tfvars
enable_wireguard        = false
enable_public_endpoint  = true
```

## Cost Optimization Tips

1. **Use preemptible GPU nodes** for non-critical workloads (up to 70% savings)
2. **Start with single-GPU nodes** for development
3. **Disable unused components** (Loki, multi-GPU support)
4. **Scale down when not in use**

## Documentation

- [Terraform Infrastructure](deploy/001-iac/README.md)
- [Setup Scripts](deploy/002-setup/README.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Security Guide](docs/SECURITY.md)

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

---

## Appendix A: Terraform Configuration Presets

The `deploy/001-iac/` directory includes several pre-configured `terraform.tfvars` examples for different use cases:

| Preset | GPU | WireGuard | Public API | Use Case |
|--------|-----|-----------|------------|----------|
| `terraform.tfvars.cost-optimized.example` | L40S | No | Yes | **Recommended for development** - Lowest cost, quick testing |
| `terraform.tfvars.cost-optimized-secure.example` | L40S | Yes | No | Development with VPN-only access |
| `terraform.tfvars.secure.example` | H100 | Yes | No | Staging with full security |
| `terraform.tfvars.production.example` | H200 | Yes | No | Production with maximum performance |
| `terraform.tfvars.example` | H100 | No | Yes | Basic template with all options documented |

> **Note:** All configurations use **private nodes** (no public IPs on K8s nodes). Access is via WireGuard VPN or public K8s API endpoint.

### Key Differences

| Preset | GPU Nodes | CPU Nodes | etcd Size | Preemptible | Security |
|--------|-----------|-----------|-----------|-------------|----------|
| **cost-optimized-secure** | 1x L40S | 2x small | 1 | Yes | VPN only |
| **cost-optimized** | 1x L40S | 2x small | 1 | Yes | Public endpoints |
| **secure** | 8x H100 | 3x medium | 3 | No | VPN only |
| **production** | 4x 8-GPU H200 | 3x large | 3 | No | VPN only |

**Recommendation:** Start with `terraform.tfvars.cost-optimized-secure.example` for development, then scale up as needed.

## Cleanup

To tear down the deployment, see [deploy/README.md](deploy/README.md#cleanup) for detailed instructions. The process involves:

1. Uninstalling Kubernetes components (in reverse order) via scripts in `deploy/002-setup/cleanup/`
2. Destroying infrastructure with `terraform destroy` in `deploy/001-iac/`
