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

