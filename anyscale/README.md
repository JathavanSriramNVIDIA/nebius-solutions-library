# Anyscale deployment on Nebius Cloud

This Terraform module will help with installing Anyscale operator on Nebius cloud.

## Requirements
- [Terraform CLI](https://developer.hashicorp.com/terraform/install)
- [Anyscale CLI](https://docs.anyscale.com/reference/quickstart-cli)

## Preparation

1. Make a copy of the configuration template: 

```bash
cp default.yaml.tpl default.yaml
```

2. Refer to documentation of the [nfs-server](https://github.com/nebius/nebius-solutions-library/tree/main/nfs-server) and [k8s-training](https://github.com/nebius/nebius-solutions-library/tree/main/k8s-training) modules on how to fill in the values of the respective sections in the `default.yaml` file. **Note:** Leave the `anyscale` section empty for now.

3. Edit the `environment.sh` file and fill in the values for `NEBIUS_TENANT_ID`, `NEBIUS_PROJECT_ID` and `NEBIUS_REGION`.

4. Load environment variables:
```bash
source ./environment.sh
```

## Installation

### Deploying NFS server and creating Object stroage bucket

1. Initialize the Terraform code in `prepare` directory: 
```bash
terraform -chdir=prepare init
```

2. Preview the deployment plan:
```bash
terraform -chdir=prepare plan
```

3. Apply the configuration:
```bash
terraform -chdir=prepare apply
```

Wait for the operation to complete.


### Registering a cluster in Anyscale and configuration
1. Run the shell script to register an Anyscale cloud:
```bash
./register.sh <cloud-name>
```

2. This command should return a cloud deployment ID that starts with `cldrsrc_`. Enter this ID into `cloud_deployment_id` key of `default.yaml`.
3. Get an [Anyscale CLI token](https://console.anyscale.com/api-keys). Enter the token into `anyscale_cli_token` key of `default.yaml`.
4. Run `terraform -chdir=prepare output object_storage_bucket_name` to get the name of the bucket that is going to store the users data. Remember the name of the bucket for the next step.
5. [Create a service account](https://docs.nebius.com/iam/service-accounts/manage) and grant it access to edit the bucket that was mentioned in the previous step. Enter access key and secret key into `object_stroage_access_key` and `object_stroage_secret_key` keys of `default.yaml` respectively.

### Deploying Kubernetes cluster and Anyscale operator
1. Initialize the Terraform code in `deploy` directory: 
```bash
terraform -chdir=deploy init
```

2. Preview the deployment plan:
```bash
terraform -chdir=deploy plan
```

3. Apply the configuration:
```bash
terraform -chdir=deploy apply
```

Wait for the operation to complete.

## Usage
You can connect to the cluster and check if the operator pod is running. If that is the case then you can start deploying your workloads via Anyscale Console.

