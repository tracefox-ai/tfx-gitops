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

# Resolve script directory to correctly find the SQL files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INIT_SQL_FILE="$SCRIPT_DIR/01_init_cluster.sql"
METRICS_SQL_FILE="$SCRIPT_DIR/create-metrics-tables.sql"

if [ ! -f "$INIT_SQL_FILE" ]; then
  echo "❌ SQL file not found: $INIT_SQL_FILE"
  exit 1
fi

if [ ! -f "$METRICS_SQL_FILE" ]; then
  echo "❌ SQL file not found: $METRICS_SQL_FILE"
  exit 1
fi

echo "🚀 Initializing ClickHouse tables on cluster '$CLUSTER_NAME'..."

# Read SQL files and replace placeholders
# We only replace {cluster}. {shard} and {replica} are internal ClickHouse macros managed by Replicated tables
INIT_SQL_CONTENT=$(sed "s/{cluster}/$CLUSTER_NAME/g" "$INIT_SQL_FILE")
METRICS_SQL_CONTENT=$(sed "s/{cluster}/$CLUSTER_NAME/g" "$METRICS_SQL_FILE")

# Execute SQL via kubectl exec and clickhouse-client
# -m: multi-line
# -n: multi-query
echo "📊 Creating main tables (logs, traces, sessions)..."
echo "$INIT_SQL_CONTENT" | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- clickhouse-client -mn --host=localhost --port=9000

echo "📈 Creating metrics tables (gauge, sum)..."
echo "$METRICS_SQL_CONTENT" | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- clickhouse-client -mn --host=localhost --port=9000

echo ""
echo "✅ ClickHouse initialization complete."
