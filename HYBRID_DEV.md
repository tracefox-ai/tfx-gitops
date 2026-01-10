# Hybrid Development Environment (K8s Infra + Local App)

This guide confirms how to run your local HyperDX application (via Docker Compose) while connecting to "production-like" infrastructure (Operators, ClickHouse, Mongo) running in your local Docker Desktop Kubernetes.

## Architecture

*   **Infrastructure (K8s)**: ClickHouse (Altinity Operator), MongoDB (Community Operator), OpenTelemetry Collector (OTEL Operator).
*   **Application (Local)**: HyperDX API & Frontend running in Docker Compose (or `yarn start`), connecting to K8s via Port Forwarding.

## Prerequisites

1.  **Docker Desktop** with Kubernetes enabled.
2.  **Infrastructure Deployed**:
    ```bash
    # Ensure ArgoCD infrastructure project is synced
    kubectl get applications -n argocd infrastructure
    ```

## Step 1: Deploy Infrastructure & Databases

1.  **Deploy Infrastructure** (Operators):
    ```bash
    kubectl apply -f argocd/projects/infrastructure.yaml
    kubectl apply -f argocd/apps/infrastructure/app-of-apps.yaml
    ```

2.  **Deploy Databases** (via Staging):
    *We deploy the staging environment to get the ClickHouse and MongoDB clusters running. You can ignore the 'staging' application pods since you'll run the app locally.*
    ```bash
    kubectl apply -f argocd/projects/staging.yaml
    kubectl apply -f argocd/apps/staging/app-of-apps.yaml
    ```
    *Wait for `chi-clickhouse-...` and `mongodb-...` pods to be Running.*

## Step 2: Start Port Forwarding

```bash
./scripts/setup-hybrid-dev.sh
```

This script will:
1.  Check for running ClickHouse, MongoDB, and OTEL pods in K8s.
2.  Port-forward the following ports to `localhost`:
    - **ClickHouse**: 8123 (HTTP), 9000 (Native)
    - **MongoDB**: 27017
    - **OTEL Collector**: 4317 (GRPC), 4318 (HTTP)

*Keep this terminal open to maintain the connections.*

## Step 2: Initialize Database (Migration)

Since the Staging environment uses the old Helm chart, the new table definitions (Clustered/Distributed) are missing. Run this one-time script to create them:

```bash
./scripts/init-clickhouse-hybrid.sh
```

## Step 3: Run Application (Local Yarn)

1.  **Install Dependencies** (if not already done):
    ```bash
    cd hyperdx
    yarn install
    ```

2.  **Run with Hybrid Environment**:
    We use `dotenvx` (included in devDependencies) or simply export the variables to run the app with the credentials from `.env.hybrid`.

    yarn build:common-utils

    ```bash
    # Option 1: Using export (simplest)
    export $(cat .env.hybrid | grep -v '^#' | xargs) && yarn app:dev

    # Option 2: Using dotenvx (if installed globally or via yarn)
    yarn dotenvx run -f .env.hybrid -- yarn app:dev
    ```

## Step 3: Verify

*   **UI**: http://localhost:8080 (or 3000 depending on config)
*   **Infrastructure**: The app should be connected to your K8s-hosted MongoDB and ClickHouse.

## Why this approach?
*   **Production Parity**: You are using the exact same Helm charts and Operators as production.
*   **Resource Efficiency**: No need to run duplicate heavy databases in Docker Compose.
*   **Dev Experience**: Fast feedback loop for application code changes.
