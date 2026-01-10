# OpenTelemetry Collector Configuration Issues

## Issues Identified

### 1. **managementState: managed (OpAMP Required)**
- **Problem**: The collector is configured with `managementState: managed`, which means it uses OpAMP supervisor and requires an OpAMP server to be running.
- **Impact**: The collector won't start until it can connect to the OpAMP server. The supervisor process runs, but the actual collector process (`/otelcontribcol`) never starts, so ports 4317/4318 aren't listening.
- **Current State**: The Helm chart doesn't explicitly set `managementState`, so the OpenTelemetry Operator is auto-detecting it based on the image (`clickstack-otel-collector` which includes OpAMP supervisor).

### 2. **OPAMP_SERVER_URL is Incorrect**
- **Problem**: In `values-staging.yaml`, `OPAMP_SERVER_URL` is set to `http://host.docker.internal:4320`
- **Impact**: `host.docker.internal` only works in Docker Desktop environments, not in Kubernetes. The collector can't reach the OpAMP server.
- **Expected**: Should point to the HyperDX app service in Kubernetes:
  - If HyperDX app is deployed: `http://clickstack-staging-app.default.svc.cluster.local:4320` or `http://clickstack-staging-app:4320`
  - If HyperDX app is NOT deployed: Should use `managementState: unmanaged` instead

### 3. **Missing managementState Configuration**
- **Problem**: The Helm chart template doesn't support configuring `managementState`
- **Impact**: Can't switch between managed (OpAMP) and unmanaged (static config) modes

## Solutions

### Option 1: Use Unmanaged Mode (Recommended for Standalone Collector)
If you don't need OpAMP remote configuration management, use unmanaged mode:

1. Add `managementState: unmanaged` to the Helm chart template
2. Set it in `values-staging.yaml`
3. The collector will use the static config directly without needing OpAMP

### Option 2: Fix OpAMP Configuration (If HyperDX App is Running)
If you need OpAMP for remote configuration:

1. Fix `OPAMP_SERVER_URL` in `values-staging.yaml` to point to the correct service
2. Ensure the HyperDX app is running and accessible
3. Keep `managementState: managed`

## Recommended Fix

### Option A: Hybrid Development (OpAMP Server on Localhost)

If you're running the OpAMP server (HyperDX app) locally and the collector in Kubernetes:

```yaml
# values-staging.yaml
managementState: "managed"
env:
  - name: OPAMP_SERVER_URL
    value: "http://host.docker.internal:4320"  # Docker Desktop
    # For other K8s: use your host IP, e.g., "http://192.168.1.100:4320"
```

**Requirements:**
1. HyperDX app must be running locally on port 4320
2. Docker Desktop Kubernetes: `host.docker.internal` should work automatically
3. Other K8s: You may need to use your host machine's IP address

**Verify OpAMP server is accessible:**
```bash
# From your local machine
curl http://localhost:4320/v1/opamp

# Test from inside a pod (if needed)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://host.docker.internal:4320/v1/opamp
```

### Option B: Standalone Collector (No OpAMP)

For a standalone collector without OpAMP:

```yaml
# values-staging.yaml
managementState: "unmanaged"
env:
  - name: OPAMP_SERVER_URL
    value: ""  # Not needed
```

This will:
- Use the static config from the Helm chart
- Start the collector immediately without waiting for OpAMP
- Make ports 4317/4318 available right away
