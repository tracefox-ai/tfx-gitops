#!/bin/bash
set -e

# Script to deploy ClickHouse Operator and ClickHouse Helm chart
# Usage: ./scripts/deploy-clickhouse.sh [staging|production]

ENVIRONMENT="${1:-staging}"
NAMESPACE="clickhouse"

echo "🚀 Deploying ClickHouse Operator and ClickHouse for environment: $ENVIRONMENT"
echo ""

# Step 1: Create namespace if it doesn't exist
echo "📦 Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Deploy ClickHouse Operator
echo ""
echo "🔧 Deploying ClickHouse Operator..."
if ! helm repo list | grep -q "^altinity[[:space:]]"; then
  helm repo add altinity https://altinity.github.io/clickhouse-operator
else
  echo "Repository 'altinity' already exists, skipping add..."
fi
helm repo update

helm upgrade --install clickhouse-operator altinity/altinity-clickhouse-operator \
  --version 0.23.* \
  --namespace "$NAMESPACE" \
  --set operator.resources.limits.cpu=200m \
  --set operator.resources.limits.memory=256Mi \
  --set operator.resources.requests.cpu=100m \
  --set operator.resources.requests.memory=128Mi \
  --wait

echo ""
echo "✅ ClickHouse Operator deployed successfully"
echo "⏳ Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l app=clickhouse-operator -n "$NAMESPACE" --timeout=300s || true

# Step 3: Deploy ClickHouse Helm chart
echo ""
echo "📊 Deploying ClickHouse cluster..."

# Determine which values file to use
VALUES_FILE="helm/clickhouse/values.yaml"
if [ "$ENVIRONMENT" = "staging" ] && [ -f "helm/clickhouse/values-staging.yaml" ]; then
  VALUES_FILE="helm/clickhouse/values-staging.yaml"
elif [ "$ENVIRONMENT" = "production" ] && [ -f "helm/clickhouse/values-prod.yaml" ]; then
  VALUES_FILE="helm/clickhouse/values-prod.yaml"
fi

if [ ! -f "$VALUES_FILE" ]; then
  echo "⚠️  Warning: Values file $VALUES_FILE not found, using default values.yaml"
  VALUES_FILE="helm/clickhouse/values.yaml"
fi

helm upgrade --install clickhouse-${ENVIRONMENT} ./helm/clickhouse \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait

echo ""
echo "✅ ClickHouse cluster deployed successfully"
echo ""
echo "📋 Checking deployment status..."
kubectl get pods -n "$NAMESPACE"
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "To check ClickHouse status:"
echo "  kubectl get chi -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "To access ClickHouse:"
echo "  kubectl port-forward -n $NAMESPACE svc/clickhouse-clickhouse-staging 8123:8123"
echo "  Then connect to: http://localhost:8123"
