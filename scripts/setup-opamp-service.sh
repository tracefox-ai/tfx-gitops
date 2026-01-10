#!/bin/bash
# Script to create a Kubernetes service that forwards to local OpAMP server
# This allows pods in Kubernetes to reach the OpAMP server running on localhost
# Usage: ./scripts/setup-opamp-service.sh [HOST_IP] [PORT]

set -e

HOST_IP="${1:-192.168.50.204}"  # Default to first non-localhost IP
OPAMP_PORT="${2:-4320}"
NAMESPACE="${3:-default}"

echo "🔧 Setting up OpAMP server access from Kubernetes"
echo "=================================================="
echo ""
echo "Host IP: $HOST_IP"
echo "OpAMP Port: $OPAMP_PORT"
echo "Namespace: $NAMESPACE"
echo ""

# Check if OpAMP server is running locally
echo "1️⃣  Checking if OpAMP server is running locally..."
if curl -s -f --max-time 2 "http://localhost:$OPAMP_PORT/v1/opamp" > /dev/null 2>&1; then
    echo "   ✅ OpAMP server is running on localhost:$OPAMP_PORT"
else
    echo "   ⚠️  Warning: OpAMP server doesn't seem to be running on localhost:$OPAMP_PORT"
    echo "   Continuing anyway..."
fi
echo ""

# Create Endpoints resource pointing to host IP
echo "2️⃣  Creating Kubernetes Endpoints for OpAMP server..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: opamp-server-local
  namespace: $NAMESPACE
subsets:
- addresses:
  - ip: $HOST_IP
  ports:
  - port: $OPAMP_PORT
    protocol: TCP
    name: http
EOF

echo "   ✅ Endpoints created"
echo ""

# Create Service pointing to the endpoints
echo "3️⃣  Creating Kubernetes Service for OpAMP server..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: opamp-server-local
  namespace: $NAMESPACE
spec:
  ports:
  - port: $OPAMP_PORT
    targetPort: $OPAMP_PORT
    protocol: TCP
    name: http
EOF

echo "   ✅ Service created"
echo ""

# Verify the service
echo "4️⃣  Verifying service..."
kubectl get svc opamp-server-local -n $NAMESPACE
kubectl get endpoints opamp-server-local -n $NAMESPACE
echo ""

# Test connectivity from a pod
echo "5️⃣  Testing connectivity from a pod..."
RESULT=$(kubectl run opamp-test-$(date +%s) \
    --image=curlimages/curl:latest \
    --rm -i --restart=Never -- \
    curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 5 "http://opamp-server-local.$NAMESPACE.svc.cluster.local:$OPAMP_PORT/v1/opamp" 2>&1 || echo "FAILED")

HTTP_CODE=$(echo "$RESULT" | grep "HTTP_CODE:" | cut -d: -f2 || echo "")
if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" != "000" ]; then
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "405" ]; then
        echo "   ✅ OpAMP server is reachable from pods!"
        echo "   Service URL: http://opamp-server-local.$NAMESPACE.svc.cluster.local:$OPAMP_PORT"
    else
        echo "   ⚠️  Got HTTP $HTTP_CODE (might be OK)"
    fi
else
    echo "   ❌ Could not reach OpAMP server from pod"
    echo "   You may need to:"
    echo "   1. Check firewall allows connections from Kubernetes pods to $HOST_IP:$OPAMP_PORT"
    echo "   2. Verify the host IP is correct: $HOST_IP"
    echo "   3. Ensure OpAMP server is listening on 0.0.0.0:$OPAMP_PORT (not just localhost)"
fi
echo ""

echo "📋 Next Steps"
echo "============="
echo ""
echo "Update values-staging.yaml:"
echo "  opampServerUrl: \"http://opamp-server-local.$NAMESPACE.svc.cluster.local:$OPAMP_PORT\""
echo ""
echo "Or if same namespace:"
echo "  opampServerUrl: \"http://opamp-server-local:$OPAMP_PORT\""
echo ""
echo "Then restart the collector:"
echo "  kubectl rollout restart deployment -n $NAMESPACE -l app=otel-collector"
echo ""
