# Setup Guide

This guide walks you through setting up the Tracefox (HyperDX) stack in the correct sequence.

## Prerequisites

- **Kubernetes Cluster**: A local cluster (e.g., Docker Desktop, Minikube, Kind)
- **kubectl**: Configured to access your cluster
- **Helm**: Version 3.x installed
- **Node.js & Yarn**: For building and running the application
- **Port availability**: Ensure ports 8123, 9000, 27017, 4318 are available for port-forwarding

## Setup Sequence

### Step 1: Deploy ClickHouse

Deploy the ClickHouse operator and cluster:

```bash
./scripts/deploy-clickhouse.sh
```

This script will:
- Create the `clickhouse` namespace
- Deploy the ClickHouse operator
- Deploy the ClickHouse cluster using the staging configuration

**Wait for ClickHouse pods to be ready before proceeding.**

Verify deployment:
```bash
kubectl get pods -n clickhouse
kubectl get chi -n clickhouse
```

### Step 2: Deploy MongoDB

Deploy the MongoDB operator and cluster:

```bash
./scripts/deploy-mongodb.sh
```

This script will:
- Create the `mongodb` namespace
- Deploy the MongoDB Community Operator
- Deploy the MongoDB cluster using the staging configuration

**⚠️ IMPORTANT: Wait for MongoDB pods to be ready before proceeding.**

Verify deployment:
```bash
kubectl get pods -n mongodb
kubectl get mongodbcommunity -n mongodb
```

### Step 3: Set Up Port Forwards

Open separate terminal windows/tabs for each port-forward (they run continuously):

**Terminal 1 - ClickHouse HTTP (port 8123):**
```bash
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-staging 8123:8123
```

**Terminal 2 - ClickHouse Native (port 9000):**
```bash
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-staging 9000:9000
```

**Terminal 3 - MongoDB (port 27017):**
```bash
kubectl port-forward -n mongodb svc/mongodb-staging-svc 27017:27017
```

Keep these port-forwards running throughout your development session.

### Step 4: Initialize ClickHouse

Initialize ClickHouse with the required tables and schema:

```bash
./scripts/init-clickhouse-hybrid.sh
./scripts/run-fix-metrics-tables.sh
```

This script will:
- Find a running ClickHouse pod
- Execute the initialization SQL to create tables and configure the cluster

Verify initialization:
```bash
kubectl exec -n clickhouse -it <clickhouse-pod-name> -- clickhouse-client --query "SHOW TABLES"
```

### Step 5: Connect to MongoDB (Optional)

You can connect to MongoDB using the following connection string:

```
mongodb://my-user:staging-password-change-me@localhost:27017/?authMechanism=SCRAM-SHA-256&authSource=admin&directConnection=true
```

**Note**: Update the password if you've customized it in your MongoDB values file.

### Step 6: Set Up OpAMP Service

Set up the OpAMP service to allow the collector to connect to a local OpAMP server:

**First, find your host machine's IP address:**
```bash
# On macOS/Linux
ifconfig | grep -E "inet " | grep -v 127.0.0.1 | head -1

# Or use this to get the first non-localhost IP
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1
```

**Then run the setup script with your host IP:**
```bash
./scripts/setup-opamp-service.sh <YOUR_HOST_IP> 4320 default
```

This script will:
- Create Kubernetes endpoints and service pointing to your local OpAMP server
- Test connectivity from within the cluster
- Verify the OpAMP server is accessible

**Note**: 
- The script defaults to `192.168.50.204:4320` if no IP is provided
- Make sure your OpAMP server (HyperDX app) is running on localhost:4320 before running this script
- If your host IP changes (e.g., after reconnecting to a different network), you'll need to update the endpoints (see Troubleshooting section)


### Step 7: Deploy OpenTelemetry Collector

Deploy the OpenTelemetry Collector:

```bash
./scripts/deploy-otel-collector.sh
```

This script will:
- Deploy the OpenTelemetry Collector using the staging configuration
- Create necessary services and deployments

Verify deployment:
```bash
kubectl get pods -n default -l app.kubernetes.io/name=otel-collector
kubectl get svc -n default -l app.kubernetes.io/name=otel-collector
```


### Step 8: Port Forward OpenTelemetry Collector

**Terminal 4 - OpenTelemetry Collector (port 4318):**
```bash
kubectl port-forward -n default svc/otel-collector-staging-otel-collector 4318:4318
```

**Note**: Port 4317 (gRPC) is also available if needed, but HTTP (4318) is typically used.

### Step 9: Build and Run the Application

Navigate to the hyperdx directory and set up the application:

```bash
cd hyperdx
yarn install
yarn build:common-utils
```

Run the application in development mode:

```bash
yarn dotenvx run -f .env.tracefox -- yarn app:dev
```

The application should now be running and connected to your local infrastructure.

## Verification

### Check Collector Logs

Monitor the OpenTelemetry Collector logs:

```bash
kubectl logs -n default -l app.kubernetes.io/name=otel-collector -f
```

Filter for errors or export activity:
```bash
kubectl logs -n default -l app.kubernetes.io/name=otel-collector -f | grep -E "error|fail|Exporting"
```

### Check Collector Agent Logs

For more detailed agent logs:
```bash
COLLECTOR_POD=$(kubectl get pods -n default -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') && kubectl exec -n default $COLLECTOR_POD -- tail -50 /etc/otel/supervisor-data/agent.log 2>/dev/null | grep -E "error|fail|clickhouse|export" | tail -10
```

### Test Data Ingestion

If you have sample data, you can test ingestion:

```bash
export CLICKSTACK_API_KEY=c138075a-8fcf-4e29-8942-60ee2475b3a6

for filename in $(tar -tf sample.tar.gz); do
  endpoint="http://localhost:4318/v1/${filename%.json}"
  echo "loading ${filename%.json}"
  tar -xOf sample.tar.gz "$filename" | while read -r line; do
    printf '%s\n' "$line" | curl -s -o /dev/null -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    -H "authorization: ${CLICKSTACK_API_KEY}" \
    --data-binary @-
  done
done
```

## Common Operations

### Restart Collector

If you need to restart the collector after configuration changes:

```bash
kubectl rollout restart deployment -n default -l app.kubernetes.io/name=otel-collector
```

### Uninstall Components

**Uninstall MongoDB:**
```bash
helm uninstall mongodb-staging -n mongodb
```

**Uninstall Collector:**
```bash
helm uninstall otel-collector-staging -n default
```

**Uninstall ClickHouse:**
```bash
helm uninstall clickhouse-staging -n clickhouse
```

## Troubleshooting

### Pods Not Starting

Check pod status and events:
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Port Forward Issues

If port-forwarding fails:
1. Ensure the service exists: `kubectl get svc -n <namespace>`
2. Check if the port is already in use: `lsof -i :<port>`
3. Verify pods are running: `kubectl get pods -n <namespace>`

### Connection Issues

- Verify all port-forwards are running
- Check firewall settings if connecting from outside the cluster
- Ensure services are properly exposed: `kubectl get svc -A`

### Collector Not Receiving Data

1. Check collector logs for errors
2. Verify collector service is accessible: `curl http://localhost:4318`
3. Check network policies if deployed
4. Verify OpAMP service is correctly configured

### OpAMP Connection Timeout

If you see errors like `dial tcp <IP>:4320: i/o timeout` in the collector logs, the OpAMP endpoints are likely pointing to the wrong host IP.

**Symptoms:**
- Collector logs show: `Failed to connect to the server` with timeout errors
- Error mentions `opamp-server-local` or `opamp-server-local.default.svc.cluster.local`

**Diagnosis:**
1. Check the current endpoints configuration:
   ```bash
   kubectl get endpoints opamp-server-local -n default -o yaml
   ```
   Look for the IP address in `subsets[0].addresses[0].ip`

2. Find your current host IP:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1
   ```

3. Verify OpAMP server is running locally:
   ```bash
   curl -s http://localhost:4320/v1/opamp -X POST -H "Content-Type: application/x-protobuf" --data-binary ""
   ```
   (A response, even an error, means the server is running)

**Fix:**
If the endpoint IP doesn't match your current host IP, update it:

```bash
# Get your current host IP
HOST_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

# Update the endpoints
kubectl patch endpoints opamp-server-local -n default --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/subsets/0/addresses/0/ip\", \"value\": \"$HOST_IP\"}]"

# Verify the update
kubectl get endpoints opamp-server-local -n default -o jsonpath='{.subsets[0].addresses[0].ip}'
```

**Alternative:** Re-run the setup script with the correct IP:
```bash
./scripts/setup-opamp-service.sh <YOUR_CURRENT_HOST_IP> 4320 default
```

**Verify the fix:**
After updating, check collector logs for successful connections:
```bash
kubectl logs -n default -l app.kubernetes.io/name=otel-collector | grep -i "connected to the server"
```
You should see messages like: `"Connected to the server."`

## Next Steps

After setup is complete:
- Configure your application to send telemetry to `http://localhost:4318`
- Access the HyperDX UI (typically at `http://localhost:8080` or as configured)
- Monitor logs and metrics through the collector
- Customize configurations in the respective Helm values files
