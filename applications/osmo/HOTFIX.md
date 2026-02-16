# OSMO on Nebius -- Hotfix Notes (Pre-6.2)

Until OSMO Release 6.2, the following manual patches are required to enable S3-compatible
object storage (e.g. Nebius Object Storage) with OSMO Datasets.

---

## 1. Patch OSMO Service and Worker Helm Charts with Extra Environment Variables

The OSMO Service and OSMO Worker Helm charts must be patched with additional environment
variables so that the backend can communicate with the S3-compatible endpoint.

**Service `extraEnv`** (see [osmo_values.yaml L54-L61](https://github.com/NVIDIA/OSMO/blob/efb7fb19a938ab8d3ae3450497430e7c68407c74/run/minimal/osmo_values.yaml#L54-L61)):

```yaml
services:
  service:
    extraEnv:
    - name: AWS_ENDPOINT_URL_S3
      value: "https://<your-s3-endpoint>"
    - name: AWS_S3_FORCE_PATH_STYLE
      value: "true"
    - name: AWS_DEFAULT_REGION
      value: "us-east-1"
    - name: OSMO_SKIP_DATA_AUTH
      value: "1"
```

**Worker `extraEnv`** (see [osmo_values.yaml L67-L73](https://github.com/NVIDIA/OSMO/blob/efb7fb19a938ab8d3ae3450497430e7c68407c74/run/minimal/osmo_values.yaml#L67-L73)):

```yaml
services:
  worker:
    extraEnv:
    - name: AWS_ENDPOINT_URL_S3
      value: "https://<your-s3-endpoint>"
    - name: AWS_S3_FORCE_PATH_STYLE
      value: "true"
    - name: AWS_DEFAULT_REGION
      value: "us-east-1"
```

---

## 2. Patch the Pod Template

The Pod Template must also be patched so that workflow pods inherit the correct S3 environment
variables. Both the user container and the `osmo-ctrl` sidecar need the same set of variables.

See the reference implementation:
[config-setup.yaml L128-L196](https://github.com/NVIDIA/OSMO/blob/efb7fb19a938ab8d3ae3450497430e7c68407c74/deployments/charts/quick-start/templates/config-setup.yaml#L128-L196)

The pod template should include the following for **both** the user container and `osmo-ctrl`:

```json
{
  "configs": {
    "default_compute": {
      "spec": {
        "containers": [
          {
            "name": "{{USER_CONTAINER_NAME}}",
            "env": [
              { "name": "AWS_ENDPOINT_URL_S3",    "value": "https://<your-s3-endpoint>" },
              { "name": "AWS_S3_FORCE_PATH_STYLE", "value": "true" },
              { "name": "AWS_DEFAULT_REGION",       "value": "us-east-1" },
              { "name": "OSMO_LOGIN_DEV",           "value": "true" },
              { "name": "OSMO_SKIP_DATA_AUTH",      "value": "1" }
            ]
          },
          {
            "name": "osmo-ctrl",
            "env": [
              { "name": "AWS_ENDPOINT_URL_S3",    "value": "https://<your-s3-endpoint>" },
              { "name": "AWS_S3_FORCE_PATH_STYLE", "value": "true" },
              { "name": "AWS_DEFAULT_REGION",       "value": "us-east-1" },
              { "name": "OSMO_LOGIN_DEV",           "value": "true" },
              { "name": "OSMO_SKIP_DATA_AUTH",      "value": "1" }
            ]
          }
        ]
      }
    }
  }
}
```

---

## 3. Bucket Path

After patching, the bucket path follows the standard S3 URI format. For example:

```
s3://osmo-kc3-dev-storage-oyqxetb0/osmo-datasets
```

You can verify the configured bucket with:

```
$ osmo bucket list
Bucket             Description                    Location                                           Mode         Default Cred
==============================================================================================================================
nebius (default)   Nebius Object Storage bucket   s3://osmo-kc3-dev-storage-oyqxetb0/osmo-datasets   read-write   Yes
```

---

## 4. Dataset Paths

Dataset paths are stored under the bucket and can be viewed via `osmo config show DATASET`:

```json
{
  "buckets": {
    "nebius": {
      "dataset_path": "s3://osmo-kc3-dev-storage-oyqxetb0/osmo-datasets",
      "region": "us-east-1",
      "check_key": false,
      "description": "Nebius Object Storage bucket",
      "mode": "read-write",
      "default_credential": {
        "access_key_id": "<ACCESS_KEY_ID>",
        "access_key": "<ACCESS_KEY>"
      }
    }
  },
  "default_bucket": "nebius"
}
```

---

## 5. Credentials

Credentials **must** be set for the S3 bucket. Without them, OSMO will return an error like:

```
Error message: Credential not set for s3://osmo-kc3-dev-storage-oyqxetb0.
Please set credentials using:
  osmo credential set my_cred --type DATA --payload access_key_id=your_s3_username access_key=your_s3_key endpoint=your_endpoint region=endpoint_region
Error code: 1
```

To configure credentials, run:

```bash
osmo credential set nebius_cred \
  --type DATA \
  --payload \
    access_key_id=<YOUR_ACCESS_KEY_ID> \
    access_key=<YOUR_ACCESS_KEY> \
    endpoint=<YOUR_S3_ENDPOINT> \
    region=us-east-1
```

Replace the placeholder values with your actual Nebius Object Storage credentials.




# Examples

## POD Template

```
jsriram@NV-HKDMBY3:.../nebius-solutions-library$ osmo config show POD_TEMPLATE
{
  "default_ctrl": {
    "spec": {
      "containers": [
        {
          "name": "osmo-ctrl",
          "resources": {
            "limits": {
              "cpu": "{{USER_CPU}}",
              "memory": "{{USER_MEMORY}}",
              "ephemeral-storage": "{{USER_STORAGE}}"
            },
            "requests": {
              "cpu": "1",
              "memory": "1Gi",
              "ephemeral-storage": "1Gi"
            }
          }
        }
      ]
    }
  },
  "default_user": {
    "spec": {
      "containers": [
        {
          "name": "{{USER_CONTAINER_NAME}}",
          "resources": {
            "limits": {
              "cpu": "{{USER_CPU}}",
              "memory": "{{USER_MEMORY}}",
              "nvidia.com/gpu": "{{USER_GPU}}",
              "ephemeral-storage": "{{USER_STORAGE}}"
            },
            "requests": {
              "cpu": "{{USER_CPU}}",
              "memory": "{{USER_MEMORY}}",
              "nvidia.com/gpu": "{{USER_GPU}}",
              "ephemeral-storage": "{{USER_STORAGE}}"
            }
          }
        }
      ]
    }
  },
  "gpu_tolerations": {
    "spec": {
      "containers": [
        {
          "env": [
            {
              "name": "AWS_ENDPOINT_URL_S3",
              "value": "https://storage.eu-north1.nebius.cloud:443"
            },
            {
              "name": "AWS_S3_FORCE_PATH_STYLE",
              "value": "true"
            },
            {
              "name": "AWS_DEFAULT_REGION",
              "value": "us-east-1"
            },
            {
              "name": "OSMO_LOGIN_DEV",
              "value": "true"
            },
            {
              "name": "OSMO_SKIP_DATA_AUTH",
              "value": "1"
            }
          ],
          "name": "{{USER_CONTAINER_NAME}}"
        },
        {
          "env": [
            {
              "name": "AWS_ENDPOINT_URL_S3",
              "value": "https://storage.eu-north1.nebius.cloud:443"
            },
            {
              "name": "AWS_S3_FORCE_PATH_STYLE",
              "value": "true"
            },
            {
              "name": "AWS_DEFAULT_REGION",
              "value": "us-east-1"
            },
            {
              "name": "OSMO_LOGIN_DEV",
              "value": "true"
            },
            {
              "name": "OSMO_SKIP_DATA_AUTH",
              "value": "1"
            }
          ],
          "name": "osmo-ctrl"
        }
      ],
      "tolerations": [
        {
          "key": "nvidia.com/gpu",
          "effect": "NoSchedule",
          "operator": "Exists"
        }
      ],
      "nodeSelector": {
        "nvidia.com/gpu.present": "true"
      }
    }
  }
}
jsriram@NV-HKDMBY3:.../nebius-solutions-library$ 
```

## DATASET

```

jsriram@NV-HKDMBY3:.../nebius-solutions-library$ osmo config show DATASET
{
  "buckets": {
    "nebius": {
      "dataset_path": "s3://osmo-kc3-dev-storage-oyqxetb0/osmo-datasets",
      "region": "us-east-1",
      "check_key": false,
      "description": "Nebius Object Storage bucket",
      "mode": "read-write",
      "default_credential": {
        "access_key_id": "NAKIRUFNRG7VJXGV5CUH",
        "access_key": "**********"
      }
    }
  },
  "default_bucket": "nebius"
}
jsriram@NV-HKDMBY3:.../nebius-solutions-library$ 

```

### Running workflow pod config

```
jsriram@NV-HKDMBY3:.../nebius-solutions-library$ kubectl describe pod 7b8980e4b73d4472-b34d044ac17b4fdf -n osmo-workflows
Name:                7b8980e4b73d4472-b34d044ac17b4fdf
Namespace:           osmo-workflows
Priority:            0
Runtime Class Name:  nvidia
Service Account:     default
Node:                computeinstance-e00q0m52nk17231fvr/10.2.0.54
Start Time:          Mon, 16 Feb 2026 12:32:49 +0100
Labels:              kai.scheduler/queue=osmo-pool-osmo-workflows-default
                     nvidia.com/gpu.present=true
                     osmo.group_name=write-test-file-group
                     osmo.group_uuid=367ab8cf5e84465f8d1eec018dc6432c
                     osmo.lead_container=true
                     osmo.platform=gpu
                     osmo.pool=default
                     osmo.priority=normal
                     osmo.retry_id=0
                     osmo.submitted_by=osmo-admin
                     osmo.task_name=write-test-file
                     osmo.task_uuid=b34d044ac17b4fdf9e97e653201c9933
                     osmo.workflow_id=test-bucket-write2-16
                     osmo.workflow_uuid=7b8980e4b73d44729681c955265a1685
                     runai/queue=osmo-pool-osmo-workflows-default
Annotations:         pod-group-name: 367ab8cf5e84465f8d1eec018dc6432c
                     received-resource-type: Regular
Status:              Running
IP:                  10.2.32.223
IPs:
  IP:  10.2.32.223
Init Containers:
  osmo-init:
    Container ID:  containerd://001fbf35d5b468a442b013c68b5f3945d20d04168426dd50cd2f22d76fcd3333
    Image:         nvcr.io/nvidia/osmo/init-container:latest
    Image ID:      nvcr.io/nvidia/osmo/init-container@sha256:76132ef5c588ba405f1abcf119bd8d4050ce70be9a75681bcd58691307308b4b
    Port:          <none>
    Host Port:     <none>
    Command:
      osmo_init
    Args:
      --data_location
      /osmo/data
      --login_location
      /osmo/login
      --user_bin_location
      /osmo/usr/bin
      --run_location
      /osmo/run
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 16 Feb 2026 12:32:51 +0100
      Finished:     Mon, 16 Feb 2026 12:32:51 +0100
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:                500m
      ephemeral-storage:  1Gi
    Requests:
      cpu:                250m
      ephemeral-storage:  1Gi
    Environment:          <none>
    Mounts:
      /osmo/data from osmo-data (rw)
      /osmo/login from osmo-login (rw)
      /osmo/login.yaml from osmo-367ab8cf5e84465f-2397df5fa78ce0801926e51abce6b8dc (rw,path="login.yaml")
      /osmo/run from osmo-run (rw)
      /osmo/user_config.yaml from osmo-367ab8cf5e84465f-e81d02a52a3a659f3f797a196334a1dc (rw,path="user_config.yaml")
      /osmo/usr/bin from osmo-usr-bin (rw)
      /osmo_binaries from osmo (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-9skzh (ro)
Containers:
  write-test-file:
    Container ID:  containerd://371c4595a946dae93a7c56fcf99965f74d0ef820c5f106fd5c359cfdadd029b9
    Image:         ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b
    Image ID:      docker.io/library/ubuntu@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b
    Port:          <none>
    Host Port:     <none>
    Command:
      /osmo/bin/osmo_exec
    Args:
      -socketPath
      /osmo/data/socket/data.sock
      -userBinPath
      /osmo/usr/bin
      -commands
      bash
      -commands
      -c
      -args
      echo "OSMO default bucket test at MEOW $(date -Iseconds)" > /osmo/data/output/test.txt
      echo "Wrote test.txt to task output (will be uploaded to default bucket)"
      cat /osmo/data/output/test.txt
      echo "Spinning for 10 seconds before stopping..."
      sleep 10
      echo "Done."

    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 16 Feb 2026 12:32:53 +0100
      Finished:     Mon, 16 Feb 2026 12:33:06 +0100
    Ready:          False
    Restart Count:  0
    Limits:
      cpu:                2
      ephemeral-storage:  1Gi
      memory:             2Gi
      nvidia.com/gpu:     1
    Requests:
      cpu:                2
      ephemeral-storage:  1Gi
      memory:             2Gi
      nvidia.com/gpu:     1
    Environment:
      OSMO_CONFIG_FILE_DIR:     <set to the key 'fileDir' in secret '367ab8cf5e84465f8d1eec018dc6432c-file-dir'>  Optional: false
      AWS_ENDPOINT_URL_S3:      https://storage.eu-north1.nebius.cloud:443
      AWS_S3_FORCE_PATH_STYLE:  true
      AWS_DEFAULT_REGION:       us-east-1
      OSMO_LOGIN_DEV:           true
      OSMO_SKIP_DATA_AUTH:      1
    Mounts:
      /osmo/bin/osmo_exec from osmo (ro,path="osmo/osmo_exec")
      /osmo/data/benchmarks from osmo-data (rw,path="benchmarks")
      /osmo/data/input from osmo-data (rw,path="input")
      /osmo/data/output from osmo-data (rw,path="output")
      /osmo/data/socket from osmo-data (rw,path="socket")
      /osmo/login/config from osmo-login (rw,path="user/config")
      /osmo/run from osmo-run (rw)
      /osmo/usr/bin from osmo-usr-bin (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-9skzh (ro)
  osmo-ctrl:
    Container ID:  containerd://0af2cb06537cdf206f57201e9f763d5576aaf046cc5ea3e94fefe24b8bb3702f
    Image:         nvcr.io/nvidia/osmo/client:latest
    Image ID:      nvcr.io/nvidia/osmo/client@sha256:db49c7336578d590c0a0e5a4f5964160a342b025057a39bdb0abb4b047027a92
    Port:          <none>
    Host Port:     <none>
    Command:
      /osmo/bin/osmo_ctrl
    Args:
      -socketPath
      /osmo/data/socket/data.sock
      -inputPath
      /osmo/data/input/
      -outputPath
      /osmo/data/output/
      -metadataFile
      /osmo/data/default_metadata.yaml
      -downloadType
      download
      -timeout
      1440
      -dataTimeout
      10
      -cacheSize
      0
      -workflow
      test-bucket-write2-16
      -groupName
      write-test-file-group
      -retryId
      0
      -logSource
      write-test-file
      -host
      osmo-nebius.csptst.nvidia.com
      -port
      443
      -scheme
      wss
      -refreshToken
      /osmo/.refresh_token
      -refreshScheme
      https
      -outputs
      dataset:nebius/mydataset3,,;;
      -userConfig
      /osmo/user_config.yaml
      -serviceConfig
      /osmo/service_config.yaml
    State:          Running
      Started:      Mon, 16 Feb 2026 12:32:55 +0100
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:                2
      ephemeral-storage:  1Gi
      memory:             2Gi
    Requests:
      cpu:                1
      ephemeral-storage:  1Gi
      memory:             1Gi
    Environment:
      OSMO_CONFIG_FILE_DIR:     <set to the key 'fileDir' in secret '367ab8cf5e84465f8d1eec018dc6432c-file-dir'>  Optional: false
      OSMO_NODE_NAME:            (v1:spec.nodeName)
      CPU_COUNT:                2
      AWS_ENDPOINT_URL_S3:      https://storage.eu-north1.nebius.cloud:443
      AWS_S3_FORCE_PATH_STYLE:  true
      AWS_DEFAULT_REGION:       us-east-1
      OSMO_LOGIN_DEV:           true
      OSMO_SKIP_DATA_AUTH:      1
    Mounts:
      /osmo/.refresh_token from osmo-367ab8cf5e84465f-396525153d86265cecbae9e0516d5f6e (rw,path=".refresh_token")
      /osmo/bin/osmo_ctrl from osmo (ro,path="osmo/osmo_ctrl")
      /osmo/data/benchmarks from osmo-data (rw,path="benchmarks")
      /osmo/data/default_metadata.yaml from osmo-367ab8cf5e84465f-a737613d24fc5815cebd0d7fdc061795 (rw,path="default_metadata.yaml")
      /osmo/data/input from osmo-data (rw,path="input")
      /osmo/data/output from osmo-data (ro,path="output")
      /osmo/data/socket from osmo-data (rw,path="socket")
      /osmo/login/config from osmo-login (rw,path="ctrl/config")
      /osmo/service_config.yaml from osmo-367ab8cf5e84465f-73f75f33cf5be7bb268a172e39206e52 (rw,path="service_config.yaml")
      /osmo/user_config.yaml from osmo-367ab8cf5e84465f-e81d02a52a3a659f3f797a196334a1dc (rw,path="user_config.yaml")
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-9skzh (ro)
Conditions:
  Type                        Status
  PodBound                    True
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       False
  ContainersReady             False
  PodScheduled                True
Volumes:
  osmo:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  osmo-data:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  osmo-login:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  osmo-usr-bin:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  osmo-run:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  osmo-367ab8cf5e84465f-2397df5fa78ce0801926e51abce6b8dc:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  osmo-367ab8cf5e84465f-2397df5fa78ce0801926e51abce6b8dc
    Optional:    false
  osmo-367ab8cf5e84465f-e81d02a52a3a659f3f797a196334a1dc:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  osmo-367ab8cf5e84465f-e81d02a52a3a659f3f797a196334a1dc
    Optional:    false
  osmo-367ab8cf5e84465f-73f75f33cf5be7bb268a172e39206e52:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  osmo-367ab8cf5e84465f-73f75f33cf5be7bb268a172e39206e52
    Optional:    false
  osmo-367ab8cf5e84465f-a737613d24fc5815cebd0d7fdc061795:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  osmo-367ab8cf5e84465f-a737613d24fc5815cebd0d7fdc061795
    Optional:    false
  osmo-367ab8cf5e84465f-396525153d86265cecbae9e0516d5f6e:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  osmo-367ab8cf5e84465f-396525153d86265cecbae9e0516d5f6e
    Optional:    false
  kube-api-access-9skzh:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   Burstable
Node-Selectors:              nvidia.com/gpu.present=true
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
                             nvidia.com/gpu:NoSchedule op=Exists
Events:
  Type    Reason     Age   From           Message
  ----    ------     ----  ----           -------
  Normal  Scheduled  20s   kai-scheduler  Successfully assigned pod osmo-workflows/7b8980e4b73d4472-b34d044ac17b4fdf to node computeinstance-e00q0m52nk17231fvr at node-pool default
  Normal  Bound      20s   binder         Pod bound successfully to node computeinstance-e00q0m52nk17231fvr
  Normal  Pulling    20s   kubelet        Pulling image "nvcr.io/nvidia/osmo/init-container:latest"
  Normal  Pulled     18s   kubelet        Successfully pulled image "nvcr.io/nvidia/osmo/init-container:latest" in 1.598s (1.598s including waiting). Image size: 100648053 bytes.
  Normal  Created    18s   kubelet        Created container: osmo-init
  Normal  Started    18s   kubelet        Started container osmo-init
  Normal  Pulling    16s   kubelet        Pulling image "ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b"
  Normal  Pulled     16s   kubelet        Successfully pulled image "ubuntu:24.04@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b" in 620ms (620ms including waiting). Image size: 29735420 bytes.
  Normal  Created    16s   kubelet        Created container: write-test-file
  Normal  Started    16s   kubelet        Started container write-test-file
  Normal  Pulling    16s   kubelet        Pulling image "nvcr.io/nvidia/osmo/client:latest"
  Normal  Pulled     14s   kubelet        Successfully pulled image "nvcr.io/nvidia/osmo/client:latest" in 1.545s (1.545s including waiting). Image size: 77542766 bytes.
  Normal  Created    14s   kubelet        Created container: osmo-ctrl
  Normal  Started    14s   kubelet        Started container osmo-ctrl
jsriram@NV-HKDMBY3:.../nebius-solutions-library$
```

### OSMO Service Pod

```
jsriram@NV-HKDMBY3:.../nebius-solutions-library$ kubectl describe pod osmo-service-6c6f8977f7-6n75m -n osmo
Name:             osmo-service-6c6f8977f7-6n75m
Namespace:        osmo
Priority:         0
Service Account:  osmo
Node:             computeinstance-e00g0rk0c56nx6xh2a/10.0.0.23
Start Time:       Fri, 13 Feb 2026 20:25:45 +0100
Labels:           app=osmo-service
                  pod-template-hash=6c6f8977f7
Annotations:      <none>
Status:           Running
IP:               10.6.33.150
IPs:
  IP:           10.6.33.150
Controlled By:  ReplicaSet/osmo-service-6c6f8977f7
Containers:
  osmo-service:
    Container ID:  containerd://fb609c9d1a44060478addc4076e74e5dffa660d7fbfb870dce747860c9dd209d
    Image:         nvcr.io/nvidia/osmo/service:latest
    Image ID:      nvcr.io/nvidia/osmo/service@sha256:f2baf2b8434d596ce883d0761bdd5cc04e5d117f2ca2e85f57a8b1d7d0a4dc5b
    Port:          <none>
    Host Port:     <none>
    Command:
      service
    Args:
      --metrics_otel_collector_component
      osmo-service
      --metrics_otel_enable
      false
      --redis_host
      redis-master.osmo.svc.cluster.local
      --redis_port
      6379
      --redis_db_number
      0
      --postgres_host
      private-rw.postgresql-e00s83j5q1g5nv2mbk.backbone-e00z4dgh3j24a2002g.msp.eu-north1.nebius.cloud
      --postgres_port
      5432
      --postgres_database_name
      osmo
      --postgres_user
      osmo_admin
      --device_endpoint
      https://auth-osmo-nebius.csptst.nvidia.com/realms/osmo/protocol/openid-connect/auth/device
      --device_client_id
      osmo-device
      --browser_endpoint
      https://auth-osmo-nebius.csptst.nvidia.com/realms/osmo/protocol/openid-connect/auth
      --browser_client_id
      osmo-browser-flow
      --token_endpoint
      https://auth-osmo-nebius.csptst.nvidia.com/realms/osmo/protocol/openid-connect/token
      --logout_endpoint
      https://auth-osmo-nebius.csptst.nvidia.com/realms/osmo/protocol/openid-connect/logout
      --service_hostname
      osmo-nebius.csptst.nvidia.com
      --osmo_image_location
      nvcr.io/nvidia/osmo
      --osmo_image_tag
      latest
      --log_level
      DEBUG
      --k8s_log_level
      WARNING
      --log_dir
      /logs
      --log_name
      api_service
    State:          Running
      Started:      Fri, 13 Feb 2026 20:25:47 +0100
    Ready:          True
    Restart Count:  0
    Liveness:       http-get http://:8000/api/version delay=0s timeout=20s period=45s #success=1 #failure=3
    Readiness:      http-get http://:8000/api/workflow%3Flimit=0&all_pools=true delay=0s timeout=20s period=45s #success=1 #failure=3
    Startup:        http-get http://:8000/api/version delay=5s timeout=3s period=5s #success=1 #failure=6
    Environment:
      OSMO_DISABLE_TASK_METRICS:  false
      OSMO_POSTGRES_HOST:         private-rw.postgresql-e00s83j5q1g5nv2mbk.backbone-e00z4dgh3j24a2002g.msp.eu-north1.nebius.cloud
      OSMO_POSTGRES_PORT:         5432
      OSMO_POSTGRES_USER:         osmo_admin
      OSMO_POSTGRES_DATABASE:     osmo
      OSMO_POSTGRES_PASSWORD:     <set to the key 'password' in secret 'postgres-secret'>  Optional: false
      METRICS_OTEL_ENABLE:        false
      AWS_ENDPOINT_URL_S3:        https://storage.eu-north1.nebius.cloud:443
      AWS_S3_FORCE_PATH_STYLE:    true
      AWS_DEFAULT_REGION:         eu-north1
      OSMO_SKIP_DATA_AUTH:        1
    Mounts:
      /home/osmo/vault-agent/secrets from vault-secrets (ro)
      /logs from logs (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-9b7zj (ro)
  envoy:
    Container ID:  containerd://ed457a00186237639c1f168a797fd087cdbdeb3c9decfc85cd927170aa8b3859
    Image:         envoyproxy/envoy:v1.29.0
    Image ID:      docker.io/envoyproxy/envoy@sha256:5f9ce783a0fcf148320e966d113b300543fc4cb7c09a5ac9104d7d43ed217820
    Ports:         8080/TCP (envoy-http), 9901/TCP (envoy-admin)
    Host Ports:    0/TCP (envoy-http), 0/TCP (envoy-admin)
    Command:
      /bin/sh
      -c
    Args:
      echo "$(date -Iseconds) Waiting for secrets to be ready..."
      # For Kubernetes secrets, just wait and start
      sleep 5
      echo "$(date -Iseconds) Starting Envoy..."
      exec /usr/local/bin/envoy -c /var/config/config.yaml --log-level info --log-path /logs/envoy.txt

    State:          Running
      Started:      Fri, 13 Feb 2026 20:25:47 +0100
    Ready:          True
    Restart Count:  0
    Limits:
      memory:  128Mi
    Requests:
      cpu:        100m
      memory:     64Mi
    Liveness:     http-get http://:9901/ready delay=10s timeout=3s period=10s #success=1 #failure=3
    Readiness:    http-get http://:9901/ready delay=5s timeout=3s period=5s #success=1 #failure=3
    Startup:      http-get http://:9901/ready delay=15s timeout=3s period=5s #success=1 #failure=3
    Environment:  <none>
    Mounts:
      /etc/envoy/secrets from envoy-secrets (ro)
      /logs from logs (rw)
      /var/config from envoy-config (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-9b7zj (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       True
  ContainersReady             True
  PodScheduled                True
Volumes:
  envoy-config:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      osmo-service-envoy-config
    Optional:  false
  envoy-secrets:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  oidc-secrets
    Optional:    false
  vault-secrets:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  vault-secrets
    Optional:    false
  logs:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  kube-api-access-9b7zj:
    Type:                     Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:   3607
    ConfigMapName:            kube-root-ca.crt
    Optional:                 false
    DownwardAPI:              true
QoS Class:                    Burstable
Node-Selectors:               <none>
Tolerations:                  node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                              node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Topology Spread Constraints:  topology.kubernetes.io/zone:ScheduleAnyway when max skew 1 is exceeded for selector app=osmo-service
Events:                       <none>
jsriram@NV-HKDMBY3:.../nebius-solutions-library

```