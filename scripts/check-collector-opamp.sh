#!/bin/bash
# Script to check if collector receives config from OpAMP server
# Usage: ./scripts/check-collector-opamp.sh

set -e

echo "🔍 Checking Collector OpAMP Configuration Status"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get collector pod name
COLLECTOR_POD=$(kubectl get pods -n default -l app=otel-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$COLLECTOR_POD" ]; then
    echo -e "${RED}❌ No collector pod found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found collector pod: $COLLECTOR_POD${NC}"
echo ""

# 1. Check OpAMP server URL configuration
echo "1️⃣  Checking OpAMP Server URL configuration..."
OPAMP_URL=$(kubectl exec -n default $COLLECTOR_POD -- env | grep OPAMP_SERVER_URL | cut -d= -f2 || echo "")
if [ -n "$OPAMP_URL" ]; then
    echo -e "${GREEN}   OpAMP Server URL: $OPAMP_URL${NC}"
else
    echo -e "${YELLOW}   ⚠️  OPAMP_SERVER_URL not set${NC}"
fi
echo ""

# 2. Check if OpAMP server is accessible from pod
if [ -n "$OPAMP_URL" ]; then
    echo "2️⃣  Testing OpAMP server connectivity from pod..."
    ENDPOINT="${OPAMP_URL}/v1/opamp"
    echo "   Testing: $ENDPOINT"
    
    # Test connectivity
    RESULT=$(kubectl run opamp-test-$(date +%s) \
        --image=curlimages/curl:latest \
        --rm -i --restart=Never -- \
        curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 5 "$ENDPOINT" 2>&1 || echo "FAILED")
    
    HTTP_CODE=$(echo "$RESULT" | grep "HTTP_CODE:" | cut -d: -f2 || echo "")
    
    if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" != "000" ]; then
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "405" ]; then
            echo -e "${GREEN}   ✅ OpAMP server is reachable (HTTP $HTTP_CODE)${NC}"
        else
            echo -e "${YELLOW}   ⚠️  OpAMP server responded with status: $HTTP_CODE${NC}"
        fi
    else
        echo -e "${RED}   ❌ OpAMP server is NOT reachable${NC}"
        echo "   Connection refused - server may not be running or not accessible"
    fi
else
    echo "2️⃣  Skipping connectivity test (no OpAMP URL configured)"
fi
echo ""

# 3. Check collector logs for OpAMP connection status
echo "3️⃣  Checking collector logs for OpAMP connection status..."
echo "   (Last 50 lines of logs)"
echo ""

# Check for connection errors
CONNECTION_ERRORS=$(kubectl logs -n default $COLLECTOR_POD --tail=100 2>&1 | grep -i "failed to connect\|connection refused" | wc -l | tr -d ' ')
if [ "$CONNECTION_ERRORS" -gt 0 ]; then
    echo -e "${RED}   ❌ Found $CONNECTION_ERRORS connection error(s)${NC}"
    echo "   Recent errors:"
    kubectl logs -n default $COLLECTOR_POD --tail=100 2>&1 | grep -i "failed to connect\|connection refused" | tail -3 | sed 's/^/      /'
else
    echo -e "${GREEN}   ✅ No connection errors found${NC}"
fi

# Check for successful connection
SUCCESS=$(kubectl logs -n default $COLLECTOR_POD --tail=100 2>&1 | grep -i "connected to\|remote config" | wc -l | tr -d ' ')
if [ "$SUCCESS" -gt 0 ]; then
    echo -e "${GREEN}   ✅ Found successful connection messages${NC}"
    kubectl logs -n default $COLLECTOR_POD --tail=100 2>&1 | grep -i "connected to\|remote config" | tail -3 | sed 's/^/      /'
fi
echo ""

# 4. Check if collector process is running (ports listening)
echo "4️⃣  Checking if collector process is running (ports 4317/4318)..."
PORTS=$(kubectl exec -n default $COLLECTOR_POD -- netstat -tln 2>/dev/null | grep -E "4317|4318" || echo "")
if [ -n "$PORTS" ]; then
    echo -e "${GREEN}   ✅ Collector ports are listening:${NC}"
    echo "$PORTS" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ Collector ports 4317/4318 are NOT listening${NC}"
    echo "   This means the collector process hasn't started"
    echo "   Likely cause: No config received from OpAMP server"
fi
echo ""

# 5. Check if config was received
echo "5️⃣  Checking if config was received from OpAMP..."
CONFIG_RECEIVED=$(kubectl logs -n default $COLLECTOR_POD --tail=200 2>&1 | grep -i "received remote config\|remote config found" | wc -l | tr -d ' ')
if [ "$CONFIG_RECEIVED" -gt 0 ]; then
    echo -e "${GREEN}   ✅ Config was received from OpAMP${NC}"
    kubectl logs -n default $COLLECTOR_POD --tail=200 2>&1 | grep -i "received remote config\|remote config found" | tail -2 | sed 's/^/      /'
else
    echo -e "${RED}   ❌ No config received from OpAMP${NC}"
    echo "   Check logs for: 'No last received remote config found'"
fi
echo ""

# 6. Check supervisor data directory
echo "6️⃣  Checking supervisor data directory for stored config..."
CONFIG_FILES=$(kubectl exec -n default $COLLECTOR_POD -- ls -la /etc/otel/supervisor-data/ 2>/dev/null | grep -i config || echo "")
if [ -n "$CONFIG_FILES" ]; then
    echo -e "${GREEN}   ✅ Found config files in supervisor data:${NC}"
    echo "$CONFIG_FILES" | sed 's/^/      /'
else
    echo -e "${YELLOW}   ⚠️  No config files found in supervisor data directory${NC}"
fi
echo ""

# Summary
echo "📋 Summary"
echo "=========="
if [ "$CONNECTION_ERRORS" -gt 0 ]; then
    echo -e "${RED}❌ ISSUE: Collector cannot connect to OpAMP server${NC}"
    echo ""
    echo "   Solutions:"
    echo "   1. Verify OpAMP server is running on localhost:4320"
    echo "      curl http://localhost:4320/v1/opamp"
    echo ""
    echo "   2. If using Docker Desktop, 'host.docker.internal' should work"
    echo "      If using other K8s, you may need to:"
    echo "      - Use your host machine's IP address"
    echo "      - Set up port-forwarding from pod to host"
    echo "      - Use a Kubernetes service if OpAMP is in cluster"
    echo ""
    echo "   3. Check firewall rules allow connections from pods to host"
    echo ""
    echo "   4. Update OPAMP_SERVER_URL in values-staging.yaml:"
    echo "      opampServerUrl: \"http://YOUR_HOST_IP:4320\""
else
    if [ -n "$PORTS" ]; then
        echo -e "${GREEN}✅ Collector is running and ports are listening${NC}"
    else
        echo -e "${YELLOW}⚠️  Collector supervisor is running but collector process hasn't started${NC}"
        echo "   This usually means config wasn't received from OpAMP"
    fi
fi
echo ""
echo "   To view full logs:"
echo "   kubectl logs -n default $COLLECTOR_POD -f"
echo ""
echo "   To check OpAMP server from localhost:"
echo "   curl -v http://localhost:4320/v1/opamp"
