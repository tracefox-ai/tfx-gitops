#!/bin/bash
set -e

# Configuration
CLUSTER_NAME="tracefox"
NAMESPACE="clickhouse"
# Find the first running ClickHouse pod
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l clickhouse.altinity.com/ready=yes -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No running ClickHouse pods found in namespace '$NAMESPACE'"
  exit 1
fi

echo "🚀 Found ClickHouse Pod: $POD_NAME"

# Resolve script directory to correctly find the SQL file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SQL_FILE="$SCRIPT_DIR/01_init_cluster.sql"

if [ ! -f "$SQL_FILE" ]; then
  echo "❌ SQL file not found: $SQL_FILE"
  exit 1
fi

echo "🚀 Initializing ClickHouse tables on cluster '$CLUSTER_NAME'..."

# Read SQL file and replace placeholders
# We only replace {cluster}. {shard} and {replica} are internal ClickHouse macros managed by Replicated tables
SQL_CONTENT=$(sed "s/{cluster}/$CLUSTER_NAME/g" "$SQL_FILE")

# Execute SQL via kubectl exec and clickhouse-client
# -m: multi-line
# -n: multi-query
echo "$SQL_CONTENT" | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- clickhouse-client -mn --host=localhost --port=9000

echo ""
echo "✅ ClickHouse initialization complete."
