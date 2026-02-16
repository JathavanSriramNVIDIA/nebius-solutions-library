Gang Scheduing, how to set it up?

This looks like a huge gap in the documentation


```
{
  "backends": [
    {
      "name": "default",
      "description": "",
      "version": "6.0.0.8fad4ecd8",
      "k8s_uid": "d376caee-1f2f-4d49-9e66-cfb496e174c1",
      "k8s_namespace": "osmo-workflows",
      "dashboard_url": "",
      "grafana_url": "",
      "tests": [],
      "scheduler_settings": {
        "scheduler_type": "default",
        "scheduler_name": "default-scheduler",
        "coscheduling": false,
        "scheduler_timeout": 30
      },
      "node_conditions": {
        "rules": {
          "Ready": "True"
        },
        "prefix": ""
      },
      "last_heartbeat": "2026-02-13T11:52:22.017365",
      "created_date": "2026-02-13T11:43:01.422639",
      "router_address": "wss://osmo-nebius.csptst.nvidia.com",
      "online": true
    }
  ]
}
```




Whole creationg of dataset, buckets etc. needs much cleaner documenntation


---

## Dataset bucket upload: "Invalid region: region was not a valid DNS name"

**Symptom:** When a workflow writes to the OSMO default (dataset) bucket (e.g. via `workflows/osmo/test_bucket_write.yaml`), the upload step fails with:

```
[write-test-file][osmo] Unknown error: Invalid region: region was not a valid DNS name.. Retrying N more times.
...
[write-test-file][osmo] test.txt: OSMODataStorageClientError: EndpointResolutionError: Invalid region: region was not a valid DNS name.
```

**Cause:** OSMO’s storage client uses boto3. Boto3 validates the bucket config’s `region` field as a DNS-style name. Nebius regions (e.g. `eu-north1`) are derived from the endpoint host (`storage.eu-north1.nebius.cloud`) and can fail this validation when passed as `region_name`, even though the actual connection is to the custom endpoint in `dataset_path`.

**Fix (in `deploy/002-setup/10-configure-dataset-bucket.sh`):** Use a boto3-acceptable region string in the bucket config sent to OSMO (e.g. `us-east-1`), while keeping the real endpoint in `dataset_path` (e.g. `tos://storage.eu-north1.nebius.cloud/<bucket>/osmo-datasets`). The script now sets:

- `S3_REGION_FOR_BOTO="us-east-1"` for the `region` field in the DATASET bucket config.
- `REGION` (derived from the endpoint) is still used only for display/logging.

The actual backend is determined by `dataset_path`; the `region` value is only to satisfy the SDK. After updating the script, re-run `10-configure-dataset-bucket.sh` and re-run the test workflow to confirm uploads succeed.




# WORKING CONFIGURATION / WORKAROUND FOR THE STORAGE ISSUE

Important Info:
The "dataset" structure in OSMO is sort of cached and references a fixed storage endpoint in the database.
This means when in a workflow:

```
    outputs:
    - dataset:
        name: bucket-test-3

```
is used, the name `bucket-test-3` is linked to the s3 storage path. If you change the dataset storage path,
it will not work until a new dataset name is created e.g. `bucket-test-4` or similar.


Below now running and working setups and configuration:


### DATASET
```
jsriram@NV-HKDMBY3:.../002-setup$ osmo config show DATASET
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

### BUCKET
```
jsriram@NV-HKDMBY3:.../002-setup$ osmo bucket list
Bucket             Description                    Location                                           Mode         Default Cred
==============================================================================================================================
nebius (default)   Nebius Object Storage bucket   s3://osmo-kc3-dev-storage-oyqxetb0/osmo-datasets   read-write   Yes


```
### WORKFLOW

```
jsriram@NV-HKDMBY3:.../002-setup$ osmo config show WORKFLOW
{
  "workflow_data": {
    "credential": {
      "access_key_id": "NAKIRUFNRG7VJXGV5CUH",
      "access_key": "**********",
      "endpoint": "s3://osmo-kc3-dev-storage-oyqxetb0",
      "region": "eu-north1"
    },
    "base_url": "",
    "websocket_timeout": 1440,
    "data_timeout": 10,
    "download_type": "download"
  },
  "workflow_log": {
    "credential": {
      "access_key_id": "NAKIRUFNRG7VJXGV5CUH",
      "access_key": "**********",
      "endpoint": "s3://osmo-kc3-dev-storage-oyqxetb0",
      "region": "eu-north1"
    }
  },
  "workflow_app": {
    "credential": null
  },
  "workflow_info": {
    "tags": [],
    "max_name_length": 64
  },
  "backend_images": {
    "init": "nvcr.io/nvidia/osmo/init-container:latest",
    "client": "nvcr.io/nvidia/osmo/client:latest",
    "credential": {
      "registry": "",
      "username": "",
      "auth": "**********"
    }
  },
  "workflow_alerts": {
    "slack_token": "**********",
    "smtp_settings": {
      "host": "",
      "sender": "",
      "password": "**********"
    }
  },
  "credential_config": {
    "disable_registry_validation": [],
    "disable_data_validation": []
  },
  "user_workflow_limits": {
    "max_num_workflows": null,
    "max_num_tasks": null,
    "jinja_sandbox_workers": 2,
    "jinja_sandbox_max_time": 0.5,
    "jinja_sandbox_memory_limit": 104857600
  },
  "plugins_config": {
    "rsync": {
      "enabled": false,
      "enable_telemetry": false,
      "read_bandwidth_limit": 2621440,
      "write_bandwidth_limit": 2621440,
      "allowed_paths": {},
      "daemon_debounce_delay": 30.0,
      "daemon_poll_interval": 120.0,
      "daemon_reconcile_interval": 60.0,
      "client_upload_rate_limit": 2097152
    }
  },
  "max_num_tasks": 20,
  "max_num_ports_per_task": 30,
  "max_retry_per_task": 0,
  "max_retry_per_job": 5,
  "default_schedule_timeout": 30,
  "default_exec_timeout": "60d",
  "default_queue_timeout": "60d",
  "max_exec_timeout": "60d",
  "max_queue_timeout": "60d",
  "force_cleanup_delay": "1h",
  "max_log_lines": 10000,
  "max_task_log_lines": 1000,
  "max_error_log_lines": 100,
  "max_event_log_lines": 100,
  "task_heartbeat_frequency": "10m"
}
jsriram@NV-HKDMBY3:.../002-setup$
```
