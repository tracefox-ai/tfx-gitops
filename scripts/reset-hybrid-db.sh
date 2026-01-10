#!/bin/bash
set -e

echo "🗑️  Resetting Databases..."

# 1. Reset ClickHouse
# We need to drop the database on the cluster.
CH_HOST="localhost"
CH_PORT="8123"
CLUSTER_NAME="tracefox"

echo "🔥 Dropping ClickHouse database 'hyperdx' on cluster '$CLUSTER_NAME'..."
echo "DROP DATABASE IF EXISTS hyperdx ON CLUSTER '$CLUSTER_NAME' SYNC" | curl -sS -X POST "http://$CH_HOST:$CH_PORT/" --data-binary @-
echo "✅ ClickHouse dropped."

# 2. Reset MongoDB
# We'll use kubectl exec to run the drop command on the primary (or any) mongo node.
# Using mongodb-staging-0 as a default guess, checking if it exists.
MONGO_POD="mongodb-staging-0"
MONGO_NS="mongodb"

echo "🔥 Dropping MongoDB database 'hyperdx'..."
# Fetch credentials again just in case (though we could hardcode for this helper)
MONGO_USER=$(kubectl get secret mongodb-staging-admin-my-user -n "$MONGO_NS" -o jsonpath="{.data.username}" | base64 -d)
MONGO_PASS=$(kubectl get secret mongodb-staging-admin-my-user -n "$MONGO_NS" -o jsonpath="{.data.password}" | base64 -d)

kubectl exec -n "$MONGO_NS" "$MONGO_POD" -- mongosh "mongodb://localhost:27017/hyperdx?authSource=admin" \
  -u "$MONGO_USER" \
  -p "$MONGO_PASS" \
  --eval "db.dropDatabase()"

echo "✅ MongoDB dropped."