OneChart is a generic Helm chart for deploying web applications and services to Kubernetes. This document covers all available values and what they do.


## Image
```yaml
image:
  repository: nginx
  tag: "latest"
  pullPolicy: IfNotPresent
```

| Field | Default | Description |
|-------|---------|-------------|
| `image.repository` | `nginx` | Container image repository |
| `image.tag` | `latest` | Image tag to deploy |
| `image.pullPolicy` | `IfNotPresent` | When to pull the image (`Always`, `IfNotPresent`, `Never`) |

**Example: private registry image:**
```yaml
image:
  repository: myregistry.example.com/myapp
  tag: "1.2.3"
  pullPolicy: Always
```


## Replicas
```yaml
replicas: 1
```

Number of pod replicas to run. Minimum `0`, maximum `16`.

> When a single replica is used alongside persistent volumes, the deployment strategy is automatically set to `Recreate` to avoid volume mount conflicts.


## Ports
### Single port (default)
```yaml
containerPort: 80
```

The port your application listens on inside the container. A Kubernetes Service is automatically created pointing to this port.

### Override the service port
```yaml
containerPort: 8080
svcPort: 80
```

Use `svcPort` to expose a different port on the Service than what the container listens on.

### Multiple ports
```yaml
ports:
  - name: http
    containerPort: 8080
  - name: grpc
    containerPort: 9090
  - name: metrics
    containerPort: 9091
```

Each entry requires a `name` and `containerPort`. Optional fields: `svcPort`, `nodePort`, `protocol` (defaults to `TCP`).


## Ingress
### Single ingress
```yaml
ingress:
  host: myapp.example.com
  ingressClassName: nginx    # defaults to "kong" if omitted
  tlsEnabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

| Field | Default | Description |
|-------|---------|-------------|
| `ingress.host` |  | Hostname where the app will be accessible |
| `ingress.ingressClassName` | `kong` | Ingress controller class |
| `ingress.tlsEnabled` | `false` | Enable TLS |
| `ingress.secretName` | `tls-<name>` | TLS secret name (auto-generated if omitted) |
| `ingress.path` | `/` | Path prefix to route |
| `ingress.pathType` | `Prefix` | Kubernetes path type (`Prefix`, `Exact`) |
| `ingress.annotations` |  | Custom ingress annotations (replaces default Kong annotations) |

> If no `annotations` are provided, Kong-specific defaults are applied (`konghq.com/strip-path`, https redirect, etc.).

### Basic Auth (Nginx)
```yaml
ingress:
  host: myapp.example.com
  nginxBasicAuth:
    user: admin
    password: secret
```

Creates an htpasswd-based Kubernetes Secret and wires up Nginx basic auth.

### Multiple paths on one host
```yaml
ingress:
  host: myapp.example.com
  paths:
    - path: /api
      pathType: Prefix
    - path: /health
      pathType: Exact
```

### Multiple ingresses (multiple hosts)
```yaml
ingresses:
  - host: myapp.example.com
    tlsEnabled: true
  - host: myapp-internal.corp.example.com
    ingressClassName: nginx
```


## Environment Variables
```yaml
vars:
  DATABASE_URL: postgres://db:5432/mydb
  LOG_LEVEL: info
  PORT: "8080"
```

All key-value pairs are injected as environment variables into the container.


## Secrets
### Kubernetes Secret (plain text, stored in the chart)
```yaml
secretEnabled: true
vars:
  SECRET_KEY: mysupersecretvalue
```

When `secretEnabled: true`, the `vars` are stored as a Kubernetes `Secret` instead of a `ConfigMap`.

### Reference an existing Secret
```yaml
secretName: my-existing-secret
```

All keys from the named secret are injected as environment variables.

### Sealed Secrets (encrypted at rest)
```yaml
sealedSecrets:
  SECRET_KEY: AgBY...  # encrypted value from kubeseal
```

Requires the [Sealed Secrets controller](https://github.com/bitnami-labs/sealed-secrets). Values are encrypted and safe to commit to source control.


## Probes
### Readiness Probe
Determines whether traffic should be sent to the pod.

```yaml
probe:
  enabled: true
  path: /health
  settings:
    initialDelaySeconds: 10
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 3
    failureThreshold: 3
```

### Liveness Probe
Determines whether the pod should be restarted. Use with caution; see [this article](https://srcco.de/posts/kubernetes-liveness-probes-are-dangerous.html).

```yaml
livenessProbe:
  enabled: true
  path: /health
  settings:
    periodSeconds: 30
    failureThreshold: 5
```

### Startup Probe
Gives slow-starting containers time to initialize before liveness checks begin.

```yaml
startupProbe:
  enabled: true
  path: /health
  settings:
    periodSeconds: 10
    failureThreshold: 30  # 30 * 10s = 5 minute window to start
```

All three probes share the same settings fields:

| Field | Default | Description |
|-------|---------|-------------|
| `initialDelaySeconds` | `0` | Seconds after container start before first check |
| `periodSeconds` | `10` | How often to perform the check |
| `successThreshold` | `1` | Consecutive successes required to be considered healthy |
| `timeoutSeconds` | `3` | Seconds before the probe times out |
| `failureThreshold` | `3` | Consecutive failures before pod is marked unhealthy |


## Resources
```yaml
resources:
  requests:
    cpu: "200m"
    memory: "200Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

| Field | Description |
|-------|-------------|
| `resources.requests` | Typical usage, used by Kubernetes scheduler for pod placement |
| `resources.limits` | Hard ceiling, CPU throttling and memory OOM kill apply at this level |
| `resources.ignore` | Set to `true` to omit all resource configuration |
| `resources.ignoreLimits` | Set to `true` to set requests but no limits |

**Example: no limits:**
```yaml
resources:
  ignoreLimits: true
  requests:
    cpu: "100m"
    memory: "128Mi"
```


## Volumes
### Persistent Volume Claim (new PVC)
```yaml
volumes:
  - name: data
    path: /data
    size: 10Gi
    storageClass: default  # "default" on Azure
```

### Use an existing PVC
```yaml
volumes:
  - name: data
    path: /data
    existingClaim: my-existing-pvc
```

### Host path (bind mount from the node)
```yaml
volumes:
  - name: host-data
    path: /app/data
    hostPath:
      path: /mnt/data
      type: DirectoryOrCreate
```

### Ephemeral (emptyDir)
```yaml
volumes:
  - name: tmp-cache
    path: /tmp/cache
    emptyDir: true
```

### Mount an existing ConfigMap as a file
```yaml
volumes:
  - existingConfigMap: my-app-config
    path: /etc/app/config.yaml
    subPath: config.yaml
```

### Mount inline file content
```yaml
volumes:
  - fileName: credentials.json
    fileContent: '{"key": "value"}'
    path: /secrets
```

### Mount an existing Secret as a file
```yaml
volumes:
  - existingSecret: my-google-credentials
    name: gcp-creds
    path: /secrets/credentials.json
    subPath: credentials.json
```

### Existing File Secrets (env-var injection from mounted secret files)
```yaml
existingFileSecrets:
  - name: my-tls-secret
    path: /certs
  - name: my-config-secret
    path: /etc/app/config.yaml
    subPath: config.yaml
```


## Autoscaling (HPA)
```yaml
autoscale:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

Requires `resources.limits.cpu` and/or `resources.limits.memory` to be set. The HPA will not be created if limits are absent.


## Pod Disruption Budget
```yaml
podDisruptionBudgetEnabled: true
```

When `true` and `replicas > 1`, a PodDisruptionBudget is created ensuring at least 1 pod stays available during node draining or maintenance. Has no effect with a single replica.


## Spread Across Nodes
```yaml
spreadAcrossNodes: true
```

Adds a `podAntiAffinity` rule using `requiredDuringSchedulingIgnoredDuringExecution` to prevent multiple pods from landing on the same node. Improves availability but requires enough nodes to place all replicas.


## Node Scheduling
### Node Selector
```yaml
nodeSelector:
  disktype: ssd
  kubernetes.io/arch: amd64
```

### Tolerations
```yaml
tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
```

Allows scheduling on nodes with matching taints (e.g., spot/preemptible instances).

### Affinity
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: topology.kubernetes.io/zone
              operator: In
              values:
                - us-east-1a
```

Raw Kubernetes affinity spec. Can be combined with `spreadAcrossNodes`.


## Security Context
### Pod-level security context
```yaml
podSecurityContext:
  fsGroup: 999
  runAsUser: 1000
  runAsGroup: 1000
  runAsNonRoot: true
```

Applied to all containers in the pod. Controls the UID/GID the processes run as and the filesystem group.

### Container-level security context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

Applied to the main container only. Defaults enforce `readOnlyRootFilesystem: true` and `allowPrivilegeEscalation: false`.


## Service Type
```yaml
# Default: ClusterIP (internal only)

# NodePort
nodePortEnabled: true
nodePort: 30080   # optional, auto-assigned if omitted

# LoadBalancer
loadbalancerEnabled: true
```

### Sticky Sessions
```yaml
stickySessions: true
```

Enables `sessionAffinity: ClientIP` on the Service with a 3-hour timeout and `externalTrafficPolicy: Local`.

### Custom Service Annotations
```yaml
serviceAnnotations:
  service.beta.kubernetes.io/aws-load-balancer-internal: "true"
```


## Prometheus Monitoring
### ServiceMonitor
```yaml
monitor:
  enabled: true
  path: /metrics        # defaults to /metrics
  scheme: http          # defaults to http
  portName: http        # defaults to first port
  scrapeTimeout: 30s    # optional
```

Creates a `ServiceMonitor` resource for Prometheus Operator. Requires the Prometheus Operator CRDs to be installed.

### PrometheusRules
```yaml
prometheusRules:
  - name: HighErrorRate
    message: "Error rate above 5%"
    expression: 'rate(http_requests_total{status=~"5.."}[5m]) > 0.05'
    for: "5m"
    runBookURL: "https://runbooks.example.com/high-error-rate"
    labels:
      severity: warning
```

Creates a `PrometheusRule` resource for alerting.


## Image Pull Secrets
```yaml
imagePullSecrets:
  - regcred
  - my-private-registry-secret
```

Names of Kubernetes Secrets of type `kubernetes.io/dockerconfigjson` used to pull images from private registries.


## Init Containers
```yaml
initContainers:
  - name: db-migrate
    image: myapp
    tag: "1.2.3"
    command: "python manage.py migrate"
    imagePullPolicy: IfNotPresent
```

Init containers run to completion before the main container starts. They share environment variables from `vars`.

> Volumes with names prefixed `shared-` or `init-` are automatically mounted into init containers.


## Sidecar Container
```yaml
sidecar:
  repository: envoyproxy/envoy
  tag: v1.28.0
  shell: /bin/sh
  command: envoy -c /etc/envoy/envoy.yaml
```

Runs a second container alongside the main container in the same pod, sharing the same network namespace and volumes.


## Command Override
```yaml
command: |
  python -m gunicorn --workers 4 myapp:app
shell: /bin/bash
```

Overrides the container's default entrypoint/command. The command is passed to the specified `shell` with `-c`.


## Deployment Strategy
```yaml
strategy: RollingUpdate  # or Recreate
```

If omitted and volumes are present with a single replica, `Recreate` is used automatically to avoid volume attachment conflicts.


## Service Account
```yaml
serviceAccount: my-service-account
```

Name of an existing Kubernetes `ServiceAccount` to assign to the pod.


## Pod Annotations and Labels
```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  co.elastic.logs/enabled: "true"

podLabels:
  tier: backend
  team: platform
```


## Service Catalog Metadata
These values are stored as annotations on the Kubernetes Service for service discovery and catalog tooling:

```yaml
gitRepository: myorg/myapp
gitSha: abc123def456
gitBranch: main

serviceName: my-api
serviceDescription: "The main REST API"
ownerName: "Platform Team"
ownerIm: "#platform-team"
documentation: "https://docs.example.com/my-api"
logs: "https://grafana.example.com/logs/my-api"
metrics: "https://grafana.example.com/dashboards/my-api"
issues: "https://github.com/myorg/myapi/issues"
traces: "https://jaeger.example.com/search?service=my-api"
```


## Name Overrides
```yaml
nameOverride: ""
fullnameOverride: ""
```

Override the chart name or fully-qualified resource name used in all Kubernetes resource names.


## Raw Spec Overrides
These allow deep merging of raw Kubernetes spec fields for advanced use cases:

### Container override
```yaml
container:
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sh", "-c", "sleep 10"]
```

### Pod spec override
```yaml
podSpec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  terminationGracePeriodSeconds: 60
```

Both are merged over the generated spec using `mergeOverwrite`, so any field set here takes precedence.


## Extra Manifests
```yaml
extraDeploy: |
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: my-extra-config
  data:
    key: value
```

Raw YAML string rendered verbatim alongside the other chart resources. Useful for deploying additional Kubernetes resources that are not supported natively by the chart.

## ExternalSecret (external-secrets.io/v1)
Use this to render an independent `ExternalSecret` resource.

```yaml
secretName: app-secrets

externalSecret:
  enabled: true
  # optional: defaults to secretName when omitted
  key: app-secrets-key
  refreshInterval: 1h0m0s
  secretStoreRef:
    name: azure-key-vault
    kind: ClusterSecretStore
```

| Field | Required | Notes |
|-------|----------|-------|
| `externalSecret.enabled` | No | Must be `true` to render the resource |
| `secretName` | Yes (when `externalSecret.enabled=true`) | Used as `ExternalSecret.metadata.name` |
| `externalSecret.key` | No | Used as `ExternalSecret.spec.dataFrom[0].extract.key`; defaults to `secretName` |
| `externalSecret.refreshInterval` | No | Defaults to `1h0m0s` |
| `externalSecret.secretStoreRef.name` | No | Defaults to `azure-key-vault` |
| `externalSecret.secretStoreRef.kind` | No | Defaults to `ClusterSecretStore` |

