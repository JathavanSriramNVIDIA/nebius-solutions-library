# Physical AI Workflow Orchestration on Nebius Cloud

Deploy [NVIDIA OSMO](https://nvidia.github.io/OSMO/main/user_guide/index.html) on [Nebius AI Cloud](https://nebius.com/ai-cloud) in minutes. Run simulation, training, and edge workflows on the wide variety of Nebius GPU instances—write once in YAML, run anywhere.

## Supported Regions

| Region | Available GPU Platforms |
|--------|----------------------|
| `eu-north1` | gpu-h100-sxm, gpu-h200-sxm, gpu-l40s-a, gpu-l40s-d |
| `eu-north2` | gpu-h200-sxm |
| `eu-west1` | gpu-h200-sxm |
| `me-west1` | gpu-b200-sxm-a (NVIDIA B200) |
| `uk-south1` | gpu-b300-sxm (NVIDIA B300) |
| `us-central1` | gpu-h200-sxm, gpu-b200-sxm (NVIDIA B200) |

## Known Gaps and TODOs

| Gap | Current Workaround | Status |
|-----|-------------------|--------|
| No managed Redis service | Deploy Redis in-cluster via Helm | Workaround in place |
| MysteryBox lacks K8s CSI integration | Scripts retrieve secrets and create K8s secrets manually | Workaround in place |
| No External DNS service | Manual DNS configuration required | Not addressed |
| No managed SSL/TLS service | certbot manual DNS-01 or cert-manager HTTP-01 | Addressed (see [SSL/TLS Setup](#option-c-ssltls-with-lets-encrypt)) |
| No public Load Balancer (ALB/NLB) | Use port-forwarding or WireGuard VPN for access | Workaround in place |
| IDP integration for Nebius | Keycloak with Envoy sidecar (OAuth2 + JWT) | Addressed (see [Keycloak Authentication](#option-d-keycloak-authentication)) |
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
│  │                   │     │  (cpu-d3)    │  │ (L40S/H100/H200/ │   │    │    │
│  │                   │     │             │  │  B200/B300)       │   │    │    │
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
./install-tools.sh        # Installs: Terraform, kubectl, Helm, Nebius CLI, OSMO CLI, cmctl
./install-tools.sh --check  # Verify without installing
```

Supports Linux, WSL, and macOS. Requires Python/pip for OSMO CLI installation. See [prerequisites README](deploy/000-prerequisites/README.md) for manual installation.

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
5. **Sets region** - Choose from `eu-north1`, `eu-north2`, `eu-west1`, `me-west1`, `uk-south1`, `us-central1`
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

4. Deploy NGINX Ingress Controller:
   ```bash
   ./03-deploy-nginx-ingress.sh
   ```
   
   This deploys the community NGINX Ingress Controller with a LoadBalancer IP. It provides path-based routing to all OSMO services (API, router, Web UI). The LoadBalancer IP is auto-detected by later scripts.

5. **(Optional) Enable TLS/SSL and Keycloak Authentication:**

   If you want HTTPS (and optionally Keycloak auth), you need **domain name(s)** with **DNS A records** pointing to the NGINX Ingress LoadBalancer public IP.
   
   First, get the LoadBalancer IP assigned in the previous step:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```
   
   Then, at your DNS provider, create **A records**:
   ```
   osmo.example.com       →  <LoadBalancer IP>   # always required for TLS
   auth-osmo.example.com  →  <LoadBalancer IP>   # only if using Keycloak
   ```
   
   > **Note:** Let's Encrypt cannot issue certificates for bare IP addresses. DNS propagation may take a few minutes; verify with `nslookup osmo.example.com` before proceeding.
   
   Once the A record(s) are in place, run the **interactive** TLS setup script:

   ```bash
   ./03a-setup-tls-certificate.sh
   ```

   The script will prompt you for:
   - Your main OSMO domain (e.g. `osmo.example.com`)
   - Your email for Let's Encrypt registration
   - Whether you want Keycloak authentication (if yes, it also obtains a cert for `auth-<domain>`)

   It creates the correct Kubernetes TLS secrets automatically:

   | Domain | Secret name | Used by |
   |--------|-------------|---------|
   | `osmo.example.com` | `osmo-tls` | OSMO service/router/UI ingresses |
   | `auth-osmo.example.com` | `osmo-tls-auth` | Keycloak ingress (only if Keycloak) |

   At the end, the script tells you which `export` commands to run. For example:

   ```bash
   # TLS only (no Keycloak)
   export OSMO_TLS_ENABLED=true
   export OSMO_INGRESS_HOSTNAME=osmo.example.com

   # TLS + Keycloak
   export OSMO_TLS_ENABLED=true
   export OSMO_INGRESS_HOSTNAME=osmo.example.com
   export DEPLOY_KEYCLOAK=true
   export KEYCLOAK_HOSTNAME=auth-osmo.example.com
   ```

   > **Tip:** You can also pre-set the environment variables to skip the prompts (useful for CI):
   > `OSMO_INGRESS_HOSTNAME`, `LETSENCRYPT_EMAIL`, and `DEPLOY_KEYCLOAK=true`.

   **Alternative:** Use `./03c-deploy-cert-manager.sh` for automated HTTP-01 challenge instead of manual DNS-01.
   
   See [SSL/TLS Setup](#option-c-ssltls-with-lets-encrypt) for details, and [Keycloak Authentication](#option-d-keycloak-authentication) if enabling auth.

6. Deploy OSMO control plane:
   ```bash
   ./04-deploy-osmo-control-plane.sh
   ```
   
   This deploys the core OSMO services:
   - Creates `osmo` namespace and PostgreSQL/MEK secrets
   - Initializes databases on Nebius Managed PostgreSQL
   - Deploys Redis and OSMO services (API, agent, worker, logger)
   - Creates Kubernetes Ingress resources for path-based routing via the NGINX Ingress Controller
   - If `DEPLOY_KEYCLOAK=true` with TLS: deploys Keycloak, enables Envoy sidecars with OAuth2/JWT authentication
   
   > **Note:** The script automatically retrieves PostgreSQL password and MEK from MysteryBox if you ran `secrets-init.sh` earlier.

7. Deploy OSMO backend operator:
   ```bash
   # If Keycloak is enabled, set DEPLOY_KEYCLOAK so the script uses
   # the Keycloak password grant flow instead of dev auth:
   export DEPLOY_KEYCLOAK=true   # only if Keycloak is enabled
   
   ./05-deploy-osmo-backend.sh
   ```
   
   The script automatically creates a service token for the backend operator:
   - **Without Keycloak:** port-forwards to OSMO service and logs in with dev auth
   - **With Keycloak:** gets a JWT via Keycloak Resource Owner Password Grant, then
     calls the OSMO REST API with the `x-osmo-auth` header to create the token
   
   It then deploys the backend operator Helm chart with the token.
   
   This deploys the backend operator that manages GPU workloads:
   - Connects to OSMO control plane via `osmo-agent` (WebSocket)
   - Configures resource pools for GPU nodes
   - Enables workflow execution on the Kubernetes cluster
   
   > **Manual alternative:** If you prefer to create the token manually, set `OSMO_SERVICE_TOKEN` environment variable before running the script.
   >
   > **Keycloak credentials:** The script defaults to `osmo-admin`/`osmo-admin`. Override with
   > `OSMO_KC_ADMIN_USER` and `OSMO_KC_ADMIN_PASS` if you changed the Keycloak user credentials.

8. Verify backend deployment:
   
   Verify the backend is registered with OSMO using the NGINX Ingress LoadBalancer IP:
   ```bash
   # Check backend registration
   curl http://<INGRESS_LB_IP>/api/configs/backend
   
   # Or via OSMO CLI
   osmo config show BACKEND default
   ```
   
   The Ingress LoadBalancer IP is shown in the output of `04-deploy-osmo-control-plane.sh`.
   You should see the backend configuration with status `ONLINE`.

9. Configure OSMO storage:
   ```bash
   ./06-configure-storage.sh
   ```
   
   The script automatically:
   - Retrieves storage bucket details from Terraform
   - Starts port-forward and logs in to OSMO
   - Configures OSMO to use Nebius Object Storage for workflow artifacts
   - Verifies the configuration
   
   > **Note:** The `osmo-storage` secret (with S3 credentials) was created automatically by `04-deploy-osmo-control-plane.sh`.

10. Access OSMO (via NGINX Ingress LoadBalancer):
   
   The NGINX Ingress Controller exposes OSMO via a LoadBalancer IP. The IP is shown in the output of `04-deploy-osmo-control-plane.sh`, or retrieve it with:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```
   
   **With TLS enabled** (if you ran step 5 with a domain, e.g. `osmo.example.com`):
   - **OSMO API**: `https://osmo.example.com/api/version`
   - **OSMO Web UI**: `https://osmo.example.com`
   
   ```bash
   osmo login https://osmo.example.com --method dev --username admin
   ```
   
   **Without TLS** (plain HTTP via LoadBalancer IP):
   - **OSMO API**: `http://<LB_IP>/api/version`
   - **OSMO Web UI**: `http://<LB_IP>`
   
   ```bash
   osmo login http://<LB_IP> --method dev --username admin
   ```
   
   > **Fallback:** If neither the domain nor the LoadBalancer IP is reachable, you can use port-forwarding:
   > ```bash
   > kubectl port-forward -n osmo svc/osmo-service 8080:80
   > osmo login http://localhost:8080 --method dev --username admin
   > ```

   > **Note:** The `service_base_url` (required for workflow execution) is automatically configured
   > by `04-deploy-osmo-control-plane.sh` using the domain (if TLS is enabled) or the LoadBalancer IP.
   > If you need to reconfigure it manually, run `./07-configure-service-url.sh`.

11. Configure pool for GPU workloads:
   
   The default pool needs GPU platform configuration to run GPU workflows. This creates a pod template with the correct node selector and tolerations for GPU nodes:
   
   ```bash
   ./08-configure-gpu-platform.sh
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

12. **Log in to OSMO** (required before CLI/browser use):

   The login method depends on whether Keycloak authentication is enabled.

   **Without Keycloak** (dev mode):
   ```bash
   osmo login https://osmo.example.com --method dev --username admin
   ```

   **With Keycloak** (recommended for all authenticated deployments):

   *Interactive -- device authorization flow (opens browser):*
   ```bash
   osmo login https://osmo.example.com
   ```
   The CLI prints a URL and a code. Open the URL in a browser, log in to Keycloak
   (test user: `osmo-admin` / `osmo-admin`), enter the code, and the CLI session is
   authenticated with a Keycloak-signed JWT that includes your RBAC roles.

   *Script / CI -- resource owner password flow (no browser):*
   ```bash
   osmo login https://osmo.example.com \
     --method password \
     --username osmo-admin \
     --password osmo-admin
   ```
   > **Security note:** The password method sends credentials directly to Keycloak.
   > Only use it for service accounts or automation; prefer the device flow for
   > interactive sessions.

   *Browser:*
   Navigate to `https://osmo.example.com` -- Envoy redirects you to the Keycloak
   login page automatically.

   > **Reference:** See [Authentication Flow](https://nvidia.github.io/OSMO/main/deployment_guide/appendix/authentication/authentication_flow.html) for the full architecture
   > (OAuth2 code flow, device flow, service-account tokens, JWT validation).

13. Run a test workflow (optional):
   
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
   
   # View workflow logs
   osmo workflow query <workflow-id> --logs
   ```
   
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

| Platform | Preset | GPUs | vCPUs | RAM | InfiniBand | Regions |
|----------|--------|------|-------|-----|------------|---------|
| `gpu-l40s-a` | `1gpu-8vcpu-32gb` | 1 | 8 | 32GB | No | eu-north1 |
| `gpu-l40s-d` | `1gpu-8vcpu-32gb` | 1 | 8 | 32GB | No | eu-north1 |
| `gpu-h100-sxm` | `1gpu-16vcpu-200gb` | 1 | 16 | 200GB | No | eu-north1 |
| `gpu-h100-sxm` | `8gpu-128vcpu-1600gb` | 8 | 128 | 1600GB | Yes | eu-north1 |
| `gpu-h200-sxm` | `1gpu-16vcpu-200gb` | 1 | 16 | 200GB | No | eu-north1, eu-north2, eu-west1, us-central1 |
| `gpu-h200-sxm` | `8gpu-128vcpu-1600gb` | 8 | 128 | 1600GB | Yes | eu-north1, eu-north2, eu-west1, us-central1 |
| `gpu-b200-sxm` | `1gpu-20vcpu-224gb` | 1 | 20 | 224GB | No | us-central1 |
| `gpu-b200-sxm` | `8gpu-160vcpu-1792gb` | 8 | 160 | 1792GB | Yes | us-central1 |
| `gpu-b200-sxm-a` | `1gpu-20vcpu-224gb` | 1 | 20 | 224GB | No | me-west1 |
| `gpu-b200-sxm-a` | `8gpu-160vcpu-1792gb` | 8 | 160 | 1792GB | Yes | me-west1 |
| `gpu-b300-sxm` | `1gpu-24vcpu-346gb` | 1 | 24 | 346GB | No | uk-south1 |
| `gpu-b300-sxm` | `8gpu-192vcpu-2768gb` | 8 | 192 | 2768GB | Yes | uk-south1 |

**Recommendation:** Use `gpu-l40s-a` for development/testing in eu-north1 (cheapest option).

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

### Option C: SSL/TLS with Let's Encrypt

Enable HTTPS for OSMO using free Let's Encrypt certificates. Two paths are available:

#### Prerequisites

- A **domain name** (e.g. `osmo.example.com`) that you control
- NGINX Ingress Controller deployed (`03-deploy-nginx-ingress.sh`)
- `certbot` installed (Path A only) or `helm` available (Path B only)

#### Path A: Interactive Certbot (DNS-01 Challenge)

Best for: users who want full manual control, or whose DNS provider has no API.

1. Run the interactive certificate setup script:
   ```bash
   ./03a-setup-tls-certificate.sh
   ```

   The script will prompt you for:
   - Your main OSMO domain (e.g. `osmo.example.com`)
   - Your email for Let's Encrypt registration
   - Whether you plan to enable Keycloak (if yes, it also obtains a cert for the auth subdomain)

   For each certificate, certbot will pause and ask you to create a DNS TXT record:
   - Record name: `_acme-challenge.<domain>`
   - Record value: (provided by certbot)
   - Wait 1-5 minutes for DNS propagation, then press Enter

   > **Non-interactive mode:** Pre-set `OSMO_INGRESS_HOSTNAME`, `LETSENCRYPT_EMAIL`, and optionally `DEPLOY_KEYCLOAK=true` to skip the prompts.

2. Enable TLS for subsequent scripts (the script will tell you which exports to run):
   ```bash
   export OSMO_TLS_ENABLED=true
   export OSMO_INGRESS_HOSTNAME=osmo.example.com
   # If Keycloak:
   export DEPLOY_KEYCLOAK=true
   export KEYCLOAK_HOSTNAME=auth-osmo.example.com
   ```

3. **Renewal:** Certificates expire after 90 days. Run before expiry:
   ```bash
   ./03b-renew-tls-certificate.sh
   ```

#### Path B: Automated cert-manager (HTTP-01 Challenge)

Best for: users who want hands-off auto-renewal. Certificates are automatically renewed.

1. Point your domain's A record to the NGINX Ingress LoadBalancer IP:
   ```bash
   # Get the LoadBalancer IP
   kubectl get svc -n ingress-nginx ingress-nginx-controller \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. Set environment variables:
   ```bash
   export OSMO_INGRESS_HOSTNAME=osmo.example.com
   export LETSENCRYPT_EMAIL=you@example.com
   ```

3. Deploy cert-manager:
   ```bash
   ./03c-deploy-cert-manager.sh
   ```

4. Enable TLS for subsequent scripts:
   ```bash
   export OSMO_TLS_ENABLED=true
   ```

   cert-manager automatically renews certificates 30 days before expiry.

#### After TLS Setup

With TLS enabled, OSMO is accessible at:
- **OSMO API**: `https://osmo.example.com/api/version`
- **OSMO Web UI**: `https://osmo.example.com`
- **OSMO CLI** (without Keycloak): `osmo login https://osmo.example.com --method dev --username admin`

> If you plan to enable **Keycloak** (Option D below), skip `--method dev` -- see
> [Step 13: Log in to OSMO](#step-13-log-in-to-osmo) for Keycloak-aware CLI login.

### Option D: Keycloak Authentication

Enable production-grade authentication for OSMO using Keycloak as the identity provider with Envoy sidecar proxies on all OSMO services. This provides OAuth2 authorization code flow (browser), device authorization flow (CLI), and service-account JWT tokens.

**Reference:**
- [OSMO Authentication Flow](https://nvidia.github.io/OSMO/main/deployment_guide/appendix/authentication/authentication_flow.html)
- [Keycloak Setup Guide](https://nvidia.github.io/OSMO/main/deployment_guide/appendix/authentication/keycloak_setup.html)

#### Prerequisites

1. **TLS must be enabled** -- complete [Option C](#option-c-ssltls-with-lets-encrypt) first. If you ran `03a-setup-tls-certificate.sh` interactively and answered "yes" to Keycloak, both certificates are already in place.
2. **DNS A records** -- both the main domain and `auth-<domain>` (e.g. `auth-osmo.example.com`) must point to the same LoadBalancer IP.

#### Enabling Keycloak

Set these environment variables before running `04-deploy-osmo-control-plane.sh`:

```bash
export DEPLOY_KEYCLOAK=true
export OSMO_INGRESS_HOSTNAME=osmo.example.com
export KEYCLOAK_HOSTNAME=auth-osmo.example.com
export OSMO_TLS_ENABLED=true

./04-deploy-osmo-control-plane.sh
```

The script will automatically:
- Deploy Keycloak in **production mode** with NGINX ingress and TLS
- Import the **official OSMO realm** from [`sample_osmo_realm.json`](deploy/002-setup/sample_osmo_realm.json) (sourced from [OSMO docs](https://nvidia.github.io/OSMO/main/deployment_guide/getting_started/deploy_service.html#post-installation-keycloak-configuration)), which includes:
  - Pre-defined **roles**: `osmo-admin`, `osmo-user`, `osmo-backend`, `grafana-user`, `grafana-admin`, `dashboard-user`, `dashboard-admin`
  - Pre-defined **groups**: `Admin`, `User`, `Backend Operator` (with correct client-role mappings)
  - Two OIDC **clients**: `osmo-device` (public, device code flow) and `osmo-browser-flow` (confidential, authorization code flow)
  - **Protocol mappers** on both clients that add a `roles` claim to the JWT token (required for OSMO RBAC)
  - Standard OIDC client scopes (profile, email, roles, etc.)
- Customize the realm JSON: replace placeholder URLs (`https://default.com`) with your actual OSMO URL and set a generated client secret
- Create a test user: `osmo-admin` / `osmo-admin` (assigned to the **Admin** group)
- Generate the `oidc-secrets` Kubernetes secret (client secret + HMAC secret for Envoy)
- Enable **Envoy sidecars** on OSMO service, router, and web-ui with:
  - OAuth2 filter for browser-based login (redirects to Keycloak)
  - JWT filter validating tokens from Keycloak (browser + device flows) and OSMO (service accounts)
- Set `services.service.auth.enabled: true` with all OIDC endpoints

#### Authentication Flow

```
Browser -> NGINX Ingress -> Envoy (OAuth2 filter) -> Keycloak -> JWT
CLI     -> NGINX Ingress -> Envoy (JWT filter)    -> validates x-osmo-auth header
```

- **Browser**: Visit `https://osmo.example.com` -- Envoy's OAuth2 filter detects no session and redirects to Keycloak login. After authenticating, the user is redirected back with cookies set (`OAuthHMAC`, `IdToken`).
- **CLI**: Run `osmo login https://osmo.example.com` -- uses the OAuth2 Device Authorization flow. The CLI opens a browser for the user to authenticate with Keycloak, then polls for the token.
- **Service accounts**: Use OSMO's `/api/auth/jwt/access_token` endpoint to exchange a service token for an OSMO-signed JWT.

#### Post-Deployment: Keycloak Admin

Access the Keycloak admin console at `https://auth-osmo.example.com/admin`:
- **Admin credentials**: `admin` / `<auto-generated password>` (shown in the script output)
- **Test user**: `osmo-admin` / `osmo-admin`

To manage users, groups, and roles for OSMO:
- Create roles in both `osmo-browser-flow` and `osmo-device` clients (e.g. `osmo-admin`, `osmo-user`)
- Create groups (e.g. `OSMO Admins`) and assign roles to groups
- Add users to groups
- See [Keycloak Group and Role Management](https://nvidia.github.io/OSMO/main/deployment_guide/appendix/authentication/keycloak_setup.html)

#### Cleanup

To remove Keycloak and disable authentication:
```bash
./cleanup/uninstall-keycloak.sh
# Then re-deploy OSMO without DEPLOY_KEYCLOAK:
unset DEPLOY_KEYCLOAK
./04-deploy-osmo-control-plane.sh
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
