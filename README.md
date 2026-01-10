# Clickstack Local Deployment

This repository contains the configuration for deploying a locally modified version of HyperDX (branded as Tracefox) using Helm charts.

## Prerequisites

- **Docker**: For building images.
- **Helm**: For managing Kubernetes deployments.
- **Kubernetes Cluster**: A local cluster (e.g., Docker Desktop, Minikube, Kind).

## Quick Start

### 1. Build the Local Image

Build the HyperDX application image with the local tag `local/hyperdx:dev`.

```bash
cd hyperdx
make build-app IMAGE_NAME_DOCKERHUB=local/hyperdx IMAGE_VERSION=dev1234 IMAGE_VERSION_SUB_TAG=""
```

### 2. Deploy with Helm

Deploy the stack using the provided Helm chart. The `values.yaml` is pre-configured to use the local image.

```bash
helm upgrade --install clickstack ./helm-charts/charts/clickstack
```

To verify the installation:

```bash
kubectl get pods
```

## Configuration

The Helm chart configuration maps the application to the locally built image:

- **Repository**: `local/hyperdx`
- **Tag**: `dev`
- **PullPolicy**: `IfNotPresent` (Ensures it uses your local build)

See `helm-charts/charts/clickstack/values.yaml` for full configuration.

## Troubleshooting

### ImagePullBackOff Errors

If you encounter `ImagePullBackOff` for auxiliary images (like `busybox` or `otel-collector`), it may be due to network timeouts pulling from the registry. You can resolve this by manually pulling the images to your local cache:

```bash
# Pull Busybox (Init Container)
docker pull busybox@sha256:1fcf5df59121b92d61e066df1788e8df0cc35623f5d62d9679a41e163b6a0cdb

# Pull Otel Collector
docker pull docker.clickhouse.com/clickhouse/clickstack-otel-collector:2.8.0
```

After pulling, restart the affected pods:

```bash
kubectl delete pod -l app=clickstack
kubectl delete pod -l app=otel-collector
```
