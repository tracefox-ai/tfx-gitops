#!/bin/bash
set -e

# Script to deploy MongoDB Operator and MongoDB Helm chart
# Usage: ./scripts/deploy-mongodb.sh [staging|production]

ENVIRONMENT="${1:-staging}"
NAMESPACE="mongodb"

echo "🚀 Deploying MongoDB Operator and MongoDB for environment: $ENVIRONMENT"
echo ""

# Step 1: Create namespace if it doesn't exist
echo "📦 Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Deploy MongoDB Operator
echo ""
echo "🔧 Deploying MongoDB Community Operator..."
if ! helm repo list | grep -q "^mongodb[[:space:]]"; then
  helm repo add mongodb https://mongodb.github.io/helm-charts
else
  echo "Repository 'mongodb' already exists, skipping add..."
fi
helm repo update

helm upgrade --install mongodb-community-operator mongodb/community-operator \
  --version 0.10.* \
  --namespace "$NAMESPACE" \
  --set operator.resources.limits.cpu=200m \
  --set operator.resources.limits.memory=256Mi \
  --set operator.resources.requests.cpu=100m \
  --set operator.resources.requests.memory=128Mi \
  --wait

echo ""
echo "✅ MongoDB Community Operator deployed successfully"
echo "⏳ Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l app=mongodb-community-operator -n "$NAMESPACE" --timeout=300s || true

# Step 3: Deploy MongoDB Helm chart
echo ""
echo "📊 Deploying MongoDB cluster..."

# Determine which values file to use
VALUES_FILE="helm/mongodb/values.yaml"
if [ "$ENVIRONMENT" = "staging" ] && [ -f "helm/mongodb/values-staging.yaml" ]; then
  VALUES_FILE="helm/mongodb/values-staging.yaml"
elif [ "$ENVIRONMENT" = "production" ] && [ -f "helm/mongodb/values-production.yaml" ]; then
  VALUES_FILE="helm/mongodb/values-production.yaml"
fi

if [ ! -f "$VALUES_FILE" ]; then
  echo "⚠️  Warning: Values file $VALUES_FILE not found, using default values.yaml"
  VALUES_FILE="helm/mongodb/values.yaml"
fi

helm upgrade --install mongodb-${ENVIRONMENT} ./helm/mongodb \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait

echo ""
echo "✅ MongoDB cluster deployed successfully"
echo ""
echo "📋 Checking deployment status..."
kubectl get pods -n "$NAMESPACE"
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "To check MongoDB status:"
echo "  kubectl get mongodbcommunity -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "To access MongoDB:"
echo "  kubectl port-forward -n $NAMESPACE svc/mongodb-${ENVIRONMENT}-svc 27017:27017"
echo "  Then connect to: mongodb://localhost:27017"
