#!/bin/bash
set -e

echo "🔍 Checking for running infrastructure pods..."
echo "If this fails, ensure you have deployed 'infrastructure' AND 'staging' ArgoCD apps."

# Helper function to check if resource exists
check_resource() {
  local namespace=$1
  local kind=$2
  local name=$3
  
  if kubectl get "$kind" "$name" -n "$namespace" >/dev/null 2>&1; then
    echo "✅ Found $kind: $name ($namespace)"
    return 0
  else
    echo "❌ Could not find $kind '$name' in namespace '$namespace'"
    return 1
  fi
}

# Check for required resources
# 1. ClickHouse Service (created by Altinity Operator for the 'staging' cluster)
check_resource "clickhouse" "svc" "clickhouse-clickhouse-staging" || echo "⚠️ ClickHouse Service not found"

# 2. MongoDB Service (created by MongoDB Operator for the 'staging' cluster)
check_resource "mongodb" "svc" "mongodb-staging-svc" || echo "⚠️ MongoDB Service not found"

echo ""
echo "🚀 Starting Port Forwarding..."
echo "Keep this terminal open to maintain connectivity."
echo ""

# Cleanup function
cleanup() {
  echo ""
  echo "🛑 Stopping port forwarding..."
  pkill -P $$
  exit 0
}
trap cleanup SIGINT SIGTERM

# Port Forward ClickHouse (HTTP: 8123, Native: 9000)
echo "🔌 Forwarding ClickHouse (clickhouse-clickhouse-staging): 8123 & 9000"
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-staging 8123:8123 9000:9000 &

# Port Forward MongoDB
echo "🔌 Forwarding MongoDB (mongodb-staging-svc): 27017"
kubectl port-forward -n mongodb svc/mongodb-staging-svc 27017:27017 &

# Port Forward OTEL Collector
# The OpenTelemetry Operator automatically creates a Service for the collector
# The service name is typically: <collector-name>-collector (e.g., otel-collector-staging-collector)
OTEL_NAMESPACE="default"
OTEL_SERVICE=""
OTEL_POD=""

# First, try to find the standalone OTEL collector service (from otel-collector chart via OpenTelemetry Operator)
# The OpenTelemetry Operator creates a service with label app.kubernetes.io/name=otel-collector
# The service name is typically <collector-name>-collector
OTEL_SERVICE=$(kubectl get svc -n "$OTEL_NAMESPACE" -l app.kubernetes.io/name=otel-collector --field-selector=metadata.name!=*headless,metadata.name!=*monitoring -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

# If service not found by label, try finding by common service name patterns
if [ -z "$OTEL_SERVICE" ]; then
  # Try common service names (OpenTelemetry Operator pattern: <name>-collector)
  for svc_name in "otel-collector-staging-collector" "otel-collector-staging" "otel-collector"; do
    if kubectl get svc "$svc_name" -n "$OTEL_NAMESPACE" >/dev/null 2>&1; then
      OTEL_SERVICE="$svc_name"
      break
    fi
  done
fi

# If service found, use it (preferred - more stable)
if [ -n "$OTEL_SERVICE" ]; then
  # Check if pods are actually running (service might exist but pods might not be ready)
  OTEL_POD_STATUS=$(kubectl get pods -n "$OTEL_NAMESPACE" -l app.kubernetes.io/name=otel-collector -o jsonpath="{.items[0].status.phase}" 2>/dev/null)
  if [ "$OTEL_POD_STATUS" != "Running" ] && [ -n "$OTEL_POD_STATUS" ]; then
    echo "⚠️ Warning: OTEL Collector pod is not Running (status: $OTEL_POD_STATUS)"
    echo "   Port forwarding will work, but health checks may fail until the pod is ready."
  fi
  echo "🔌 Forwarding OTEL Collector Service ($OTEL_SERVICE): 4317 & 4318"
  kubectl port-forward -n "$OTEL_NAMESPACE" svc/$OTEL_SERVICE 4317:4317 4318:4318 &
else
  # Fall back to pod forwarding (for clickstack or if service doesn't exist)
  echo "⚠️ OTEL Collector service not found, trying pod..."
  OTEL_POD=$(kubectl get pods -n "$OTEL_NAMESPACE" -l app.kubernetes.io/name=otel-collector -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
  
  # If not found, try the clickstack OTEL collector (if enabled)
  if [ -z "$OTEL_POD" ]; then
    OTEL_POD=$(kubectl get pods -n "$OTEL_NAMESPACE" -l app.kubernetes.io/name=clickstack -l app=otel-collector -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
  fi
  
  if [ -n "$OTEL_POD" ]; then
    echo "🔌 Forwarding OTEL Collector Pod ($OTEL_POD): 4317 & 4318"
    kubectl port-forward -n "$OTEL_NAMESPACE" pod/$OTEL_POD 4317:4317 4318:4318 &
  else
    echo "⚠️ Could not find OTEL Collector service or pod in '$OTEL_NAMESPACE' namespace. Skipping."
    echo "   Note: OTEL collector is needed if your local app sends telemetry data."
  fi
fi

# Wait indefinitely
wait
