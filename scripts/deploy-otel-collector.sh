#!/bin/bash
set -e

# Script to deploy OpenTelemetry Collector Helm chart
# Usage: ./scripts/deploy-otel-collector.sh [staging|production]

ENVIRONMENT="${1:-staging}"

echo "🚀 Deploying OpenTelemetry Collector for environment: $ENVIRONMENT"
echo ""

# Determine which values file to use
VALUES_FILE="helm/otel-collector/values.yaml"
if [ "$ENVIRONMENT" = "staging" ] && [ -f "helm/otel-collector/values-staging.yaml" ]; then
  VALUES_FILE="helm/otel-collector/values-staging.yaml"
elif [ "$ENVIRONMENT" = "production" ] && [ -f "helm/otel-collector/values-production.yaml" ]; then
  VALUES_FILE="helm/otel-collector/values-production.yaml"
fi

if [ ! -f "$VALUES_FILE" ]; then
  echo "⚠️  Warning: Values file $VALUES_FILE not found, using default values.yaml"
  VALUES_FILE="helm/otel-collector/values.yaml"
fi

# Get namespace from values file
COLLECTOR_NAMESPACE=$(grep '^namespace:' "$VALUES_FILE" | awk '{print $2}' | tr -d '"' || echo 'default')

# Step 1: Create namespace if it doesn't exist
echo "📦 Creating namespace '$COLLECTOR_NAMESPACE'..."
kubectl create namespace "$COLLECTOR_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Deploy OpenTelemetry Collector Helm chart
echo ""
echo "📊 Deploying OpenTelemetry Collector..."

helm upgrade --install otel-collector-${ENVIRONMENT} ./helm/otel-collector \
  --namespace "$COLLECTOR_NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait

echo ""
echo "✅ OpenTelemetry Collector deployed successfully"
echo ""
echo "📋 Checking deployment status..."
kubectl get deployment -n "$COLLECTOR_NAMESPACE" -l app.kubernetes.io/name=otel-collector
kubectl get service -n "$COLLECTOR_NAMESPACE" -l app.kubernetes.io/name=otel-collector
kubectl get pods -n "$COLLECTOR_NAMESPACE" -l app.kubernetes.io/name=otel-collector
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "To check OpenTelemetry Collector status:"
echo "  kubectl get deployment -n $COLLECTOR_NAMESPACE -l app.kubernetes.io/name=otel-collector"
echo "  kubectl get pods -n $COLLECTOR_NAMESPACE -l app.kubernetes.io/name=otel-collector"
echo "  kubectl get service -n $COLLECTOR_NAMESPACE -l app.kubernetes.io/name=otel-collector"
echo ""
echo "To access OpenTelemetry Collector:"
echo "  kubectl port-forward -n $COLLECTOR_NAMESPACE svc/otel-collector-${ENVIRONMENT} 4317:4317"
echo "  Then connect to:"
echo "    - gRPC: http://localhost:4317"
echo "    - HTTP: http://localhost:4318"
echo "    - Fluentd: localhost:24225"
echo "    - Health: http://localhost:13133"
echo "    - Metrics: http://localhost:8888"
