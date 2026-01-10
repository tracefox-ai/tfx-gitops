# OpenTelemetry Collector Helm Chart

A Helm chart for deploying OpenTelemetry Collector using the OpenTelemetry Operator.

## Overview

This chart deploys an OpenTelemetry Collector as a Kubernetes Custom Resource (CRD) managed by the OpenTelemetry Operator. This approach provides:

- **Dynamic Configuration**: The operator can manage collector lifecycle and configuration
- **Operator Management**: Automatic reconciliation and health monitoring
- **Flexible Deployment Modes**: Supports deployment, daemonset, sidecar, and statefulset modes
- **Integration Ready**: Pre-configured for ClickHouse and HyperDX integration

## Prerequisites

- Kubernetes 1.23+
- OpenTelemetry Operator installed (see `argocd/apps/infrastructure/opentelemetry-operator.yaml`)
- Helm 3.0+

## Installation

### Using ArgoCD (Recommended)

The chart is configured to be deployed via ArgoCD:

- **Staging**: `argocd/apps/staging/otel-collector.yaml`
- **Production**: `argocd/apps/production/otel-collector.yaml`

### Using Helm CLI

```bash
# Staging
helm install otel-collector-staging ./helm/otel-collector \
  -f helm/otel-collector/values-staging.yaml \
  -n default

# Production
helm install otel-collector-production ./helm/otel-collector \
  -f helm/otel-collector/values-production.yaml \
  -n default
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable/disable the collector | `true` |
| `mode` | Deployment mode (deployment, daemonset, sidecar, statefulset) | `deployment` |
| `managementState` | Management mode: `managed` (OpAMP) or `unmanaged` (static config) | Auto-detected by operator |
| `replicas` | Number of replicas (for deployment/statefulset) | `1` |
| `image.repository` | Container image repository | `docker.clickhouse.com/clickhouse/clickstack-otel-collector` |
| `image.tag` | Container image tag | Chart AppVersion |
| `namespace` | Target namespace | `default` |
| `env` | Environment variables | See values.yaml |
| `config` | Custom OpenTelemetry config (YAML string) | Auto-generated from env vars |
| `resources` | Resource limits and requests | `{}` |

### Environment Variables

The collector uses environment variables for configuration:

- `CLICKHOUSE_ENDPOINT`: ClickHouse native protocol endpoint
- `CLICKHOUSE_SERVER_ENDPOINT`: ClickHouse server endpoint
- `CLICKHOUSE_PROMETHEUS_METRICS_ENDPOINT`: ClickHouse Prometheus metrics endpoint
- `CLICKHOUSE_USER`: ClickHouse username
- `CLICKHOUSE_PASSWORD`: ClickHouse password (can use secretKeyRef)
- `HYPERDX_OTEL_EXPORTER_CLICKHOUSE_DATABASE`: Target database name
- `HYPERDX_LOG_LEVEL`: Log level (info, debug, etc.)
- `OPAMP_SERVER_URL`: OpAMP server URL (required if `managementState: managed`, not needed for `unmanaged`)
- `HYPERDX_API_KEY`: API key for HyperDX (optional, from secret)

### Management State

The collector supports two management modes:

- **`unmanaged`** (Recommended for standalone): Uses static configuration from the Helm chart. The collector starts immediately and doesn't require an OpAMP server.
- **`managed`**: Uses OpAMP supervisor for remote configuration management. Requires `OPAMP_SERVER_URL` to be set and the OpAMP server to be accessible.

**Note**: If `managementState` is not set, the OpenTelemetry Operator will auto-detect it based on the container image. The `clickstack-otel-collector` image includes OpAMP supervisor, so it defaults to `managed` mode.

### Custom Configuration

You can provide a custom OpenTelemetry Collector configuration:

```yaml
config: |
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
  processors:
    batch:
  exporters:
    clickhouse:
      endpoint: ${CLICKHOUSE_ENDPOINT}
      database: ${HYPERDX_OTEL_EXPORTER_CLICKHOUSE_DATABASE}
  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch]
        exporters: [clickhouse]
```

If `config` is empty, the chart will use a default configuration that works with the environment variables.

## Deployment Modes

### Deployment (Default)

Standard Kubernetes deployment with configurable replicas:

```yaml
mode: deployment
replicas: 3
```

### DaemonSet

One collector per node:

```yaml
mode: daemonset
```

### Sidecar

Deploy as sidecar to other pods (requires additional configuration):

```yaml
mode: sidecar
```

### StatefulSet

Stateful deployment for stateful collectors:

```yaml
mode: statefulset
replicas: 3
```

## Examples

### Basic Staging Setup

```yaml
# values-staging.yaml
namespace: "default"

env:
  - name: CLICKHOUSE_ENDPOINT
    value: "tcp://clickhouse-staging.clickhouse.svc.cluster.local:9000"
  - name: CLICKHOUSE_USER
    value: "otelcollector"
  - name: CLICKHOUSE_PASSWORD
    value: "password"
```

### Production with Secrets

```yaml
# values-production.yaml
env:
  - name: CLICKHOUSE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: clickhouse-secret
        key: password
  - name: HYPERDX_API_KEY
    valueFrom:
      secretKeyRef:
        name: hyperdx-secrets
        key: api-key

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### With OpAMP (Remote Management)

#### OpAMP Server in Kubernetes

```yaml
managementState: "managed"
env:
  - name: OPAMP_SERVER_URL
    value: "http://clickstack-staging-app.default.svc.cluster.local:4320"
  - name: HYPERDX_API_KEY
    valueFrom:
      secretKeyRef:
        name: hyperdx-secrets
        key: api-key
```

#### OpAMP Server on Localhost (Hybrid Development)

For running HyperDX app locally while collector is in Kubernetes:

```yaml
managementState: "managed"
env:
  - name: OPAMP_SERVER_URL
    value: "http://host.docker.internal:4320"  # Docker Desktop
    # For other K8s: use host IP, e.g., "http://192.168.1.100:4320"
```

**Requirements:**
- HyperDX app must be running locally on port 4320
- Docker Desktop: `host.docker.internal` works automatically
- Other K8s: Use your host machine's IP address or set up a bridge service

**Verify connectivity:**
```bash
# Test from inside a pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://host.docker.internal:4320/v1/opamp
```

## Verification

Check the collector status:

```bash
# Check the OpenTelemetryCollector resource
kubectl get opentelemetrycollector -n default

# Check pods
kubectl get pods -n default -l app.kubernetes.io/name=otel-collector

# Check logs
kubectl logs -n default -l app.kubernetes.io/name=otel-collector

# Describe the resource for details
kubectl describe opentelemetrycollector otel-collector-staging -n default
```

## Troubleshooting

### Collector Not Starting

1. Check operator logs:
   ```bash
   kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator
   ```

2. Check collector resource status:
   ```bash
   kubectl describe opentelemetrycollector <name> -n <namespace>
   ```

3. Verify ClickHouse connectivity:
   ```bash
   kubectl exec -it <collector-pod> -n <namespace> -- env | grep CLICKHOUSE
   ```

### Configuration Issues

- Ensure environment variables are correctly set
- Check that ClickHouse endpoints are accessible from the collector namespace
- Verify secrets exist if using `valueFrom.secretKeyRef`

### Operator Not Managing Collector

- Verify the OpenTelemetry Operator is running:
  ```bash
  kubectl get pods -n opentelemetry-operator-system
  ```
- Check CRD is installed:
  ```bash
  kubectl get crd opentelemetrycollectors.opentelemetry.io
  ```

## Uninstallation

```bash
# Via Helm
helm uninstall otel-collector-staging -n default

# Via ArgoCD
# Delete the Application resource or use ArgoCD UI
```

## Migration from Deployment-based Collector

If you're migrating from the deployment-based collector in the `clickstack` chart:

1. Disable the collector in clickstack: `otel.enabled: false`
2. Deploy this chart with matching configuration
3. Update any service references to use the new collector service name
4. The operator-managed collector will create its own Service automatically

## Support

For issues or questions, contact the TraceFox team at support@tracefox.ai
