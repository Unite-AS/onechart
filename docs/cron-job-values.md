The `cron-job` chart deploys a Kubernetes `CronJob` resource for running scheduled tasks. This document covers all available values and what they do.


## Image
```yaml
image:
  repository: debian
  tag: stable-slim
```

| Field | Default | Description |
|-------|---------|-------------|
| `image.repository` | `debian` | Container image repository |
| `image.tag` | `stable-slim` | Image tag to run |

**Example:**
```yaml
image:
  repository: myregistry.example.com/my-job
  tag: "2.1.0"
```


## Schedule
```yaml
schedule: "*/5 * * * *"
```

Standard 5-field cron expression controlling when the job runs.

**Common examples:**

| Expression | Meaning |
|------------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Every hour |
| `0 2 * * *` | Every day at 2:00 AM |
| `0 9 * * 1-5` | Weekdays at 9:00 AM |
| `0 0 1 * *` | First day of each month at midnight |


## Command
```yaml
command: |
  echo "Starting job"
  python /app/run.py --mode batch
shell: "/bin/sh"
```

| Field | Default | Description |
|-------|---------|-------------|
| `command` | `echo "I'm alive"` | The shell script or command to execute |
| `shell` | `/bin/sh` | The shell binary used to run the command |
| `overrideCommand` | `true` | When `true`, overrides the container's default entrypoint with `command` |

The command is passed to the shell as: `<shell> -c <command>`.

**Example: Python job with bash:**
```yaml
command: |
  set -e
  python /app/sync.py --env production
shell: /bin/bash
overrideCommand: true
```

**Example: using the image's default entrypoint (no override):**
```yaml
overrideCommand: false
```


## Environment Variables
```yaml
vars:
  DATABASE_URL: postgres://db:5432/mydb
  BATCH_SIZE: "500"
  DRY_RUN: "false"
```

All key-value pairs are injected as environment variables into the job container.


## Secrets
### Kubernetes Secret
```yaml
secret:
  enabled: true
vars:
  API_KEY: mysecretapikey
```

When `secret.enabled: true`, the `vars` are stored in a Kubernetes `Secret` instead of a `ConfigMap`. Note that Kubernetes secrets are base64-encoded but not encrypted by default.

### Sealed Secrets (encrypted at rest)
```yaml
sealedSecrets:
  API_KEY: AgBY...   # value encrypted with kubeseal
  DB_PASSWORD: AgCZ...
```

Requires the [Sealed Secrets controller](https://github.com/bitnami-labs/sealed-secrets). Encrypted values are safe to commit to source control.


### ExternalSecret (External Secrets Operator)
Use this when your secrets are managed in an external backend (for example Azure Key Vault) and synced by `external-secrets.io`.

**Preferred (multiple resources):**
```yaml
externalSecrets:
  - name: app-secrets
    key: app-secrets-key
    refreshInterval: 30m
    secretStoreRef:
      name: my-kv
      kind: ClusterSecretStore
  - name: db-secrets
    secretStoreRef:
      name: team-kv
```

One `ExternalSecret` resource is rendered per `externalSecrets` entry.

| Field | Default | Description |
|-------|---------|-------------|
| `externalSecrets[].name` | `.Values.secretName` | Kubernetes `Secret` name to create |
| `externalSecrets[].key` | `externalSecrets[].name` | External backend key/path to extract via `dataFrom.extract.key` |
| `externalSecrets[].refreshInterval` | `1h0m0s` | Reconciliation interval |
| `externalSecrets[].secretStoreRef.name` | `azure-key-vault` | External Secrets store name |
| `externalSecrets[].secretStoreRef.kind` | `ClusterSecretStore` | Store kind |

**Legacy (single resource):**
```yaml
secretName: app-secrets
externalSecret:
  enabled: true
  key: app-secrets-key
  refreshInterval: 30m
  secretStoreRef:
    name: my-kv
    kind: ClusterSecretStore
```

If `externalSecrets` is empty and `externalSecret.enabled: true`, the chart maps this legacy shape into a single `externalSecrets` entry for backward compatibility.


## Volumes
### Persistent Volume Claim (new PVC)
```yaml
volumes:
  - name: job-output
    path: /output
    size: 20Gi
    storageClass: default
```

| Field | Default | Description |
|-------|---------|-------------|
| `name` | `data` | Volume name (identifier) |
| `path` | `/data` | Mount path inside the container |
| `size` | `10Gi` | PVC storage size |
| `storageClass` | | Storage class slug (e.g., `standard` on GCP, `default` on Azure, `do-block-storage` on DigitalOcean) |

**Example: multiple volumes:**
```yaml
volumes:
  - name: input-data
    path: /input
    size: 50Gi
    storageClass: standard
  - name: output-data
    path: /output
    size: 10Gi
    storageClass: standard
```


## Resources
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"
```

| Field | Description |
|-------|-------------|
| `resources.requests` | CPU and memory the scheduler will reserve for this job |
| `resources.limits` | Hard ceiling; CPU throttling and OOM kill apply at this level |

Defaults to `{}` (no resource constraints).

**Example: memory-intensive job:**
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "4Gi"
  limits:
    cpu: "500m"
    memory: "8Gi"
```


## Job Constraints
```yaml
constraints:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 300
```

| Field | Default | Description |
|-------|---------|-------------|
| `constraints.successfulJobsHistoryLimit` | `1` | Number of successful job pods to retain for inspection |
| `constraints.failedJobsHistoryLimit` | `1` | Number of failed job pods to retain for debugging |
| `constraints.concurrencyPolicy` | `Forbid` | How to handle concurrent runs: `Forbid` (skip if already running), `Allow`, or `Replace` |
| `constraints.startingDeadlineSeconds` | `120` | Seconds within which the job must start; missed starts are counted as failures |

**Example: allow concurrent runs and keep more history:**
```yaml
constraints:
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 10
  concurrencyPolicy: Allow
  startingDeadlineSeconds: 600
```


## Node Scheduling
### Node Selector
```yaml
nodeSelector:
  workload-type: batch
  kubernetes.io/arch: amd64
```

Restricts the job to nodes matching all specified labels.

### Tolerations
```yaml
tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
```

Allows the job to be scheduled on nodes with matching taints (e.g., spot/preemptible nodes for cost savings).

### Affinity
```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
            - key: topology.kubernetes.io/zone
              operator: In
              values:
                - us-east-1a
```

Raw Kubernetes affinity spec for fine-grained placement control.


## Pod Annotations
```yaml
podAnnotations:
  co.elastic.logs/enabled: "true"
  co.elastic.logs/json.keys_under_root: "true"
```

Annotations added to the job pod's metadata. Useful for log shippers, service meshes, and other pod-level integrations.


## Security Context
### Pod Security Context (`podSecurityContext`)
```yaml
podSecurityContext:
  fsGroup: 999
  runAsUser: 621
  runAsGroup: 999
  runAsNonRoot: true
```

Applied at `spec.jobTemplate.spec.template.spec.securityContext`.

Defaults (when not set):
- `runAsNonRoot: true`
- `runAsUser: 621`
- `runAsGroup: 999`

Any additional Kubernetes pod security context fields (for example `fsGroup`) are merged in.

### Container Security Context (`securityContext`)
```yaml
securityContext:
  runAsUser: 621
  runAsGroup: 999
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

Applied at `spec.jobTemplate.spec.template.spec.containers[0].securityContext`.

Defaults (when not set):
- `runAsNonRoot: true`
- `runAsUser: 621`
- `runAsGroup: 999`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`

Any additional Kubernetes container security context fields are merged in.


## Image Pull Secrets
```yaml
imagePullSecrets:
  - regcred
  - my-private-registry-secret
```

Names of Kubernetes Secrets of type `kubernetes.io/dockerconfigjson` used to authenticate against private container registries.


## Full Example
```yaml
image:
  repository: myorg/data-sync-job
  tag: "3.4.1"

schedule: "0 3 * * *"   # every day at 3am
command: |
  set -e
  echo "Starting daily data sync..."
  python /app/sync.py --date $(date +%Y-%m-%d)
shell: /bin/bash
overrideCommand: true

vars:
  LOG_LEVEL: info
  OUTPUT_PATH: /output

sealedSecrets:
  DATABASE_URL: AgBY...
  API_TOKEN: AgCZ...

volumes:
  - name: output
    path: /output
    size: 50Gi
    storageClass: standard

resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2000m"
    memory: "4Gi"

constraints:
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 300

tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"

podSecurityContext:
  fsGroup: 999
  runAsNonRoot: true
  runAsUser: 621
  runAsGroup: 999

securityContext:
  runAsNonRoot: true
  runAsUser: 621
  runAsGroup: 999
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```
