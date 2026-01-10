#!/bin/bash
# Script to create missing ClickHouse metrics tables
# Usage: ./scripts/create-clickhouse-metrics-tables.sh [DATABASE] [CLICKHOUSE_ENDPOINT]

set -e

DATABASE="${1:-tracefox}"
CLICKHOUSE_ENDPOINT="${2:-clickhouse-clickhouse-staging.clickhouse.svc.cluster.local:9000}"
CLICKHOUSE_USER="${3:-user2}"
CLICKHOUSE_PASSWORD="${4:-password}"

echo "🔧 Creating ClickHouse Metrics Tables"
echo "======================================"
echo ""
echo "Database: $DATABASE"
echo "Endpoint: $CLICKHOUSE_ENDPOINT"
echo "User: $CLICKHOUSE_USER"
echo ""

# Check if clickhouse-client is available
if ! command -v clickhouse-client &> /dev/null; then
    echo "⚠️  clickhouse-client not found. Using kubectl exec instead..."
    USE_KUBECTL=true
else
    USE_KUBECTL=false
fi

# Create tables SQL
SQL=$(cat <<EOFSQL
CREATE DATABASE IF NOT EXISTS ${DATABASE};

-- OTEL METRICS GAUGE
CREATE TABLE IF NOT EXISTS ${DATABASE}.otel_metrics_gauge
(
    ResourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    ResourceSchemaUrl String CODEC(ZSTD(1)),
    ScopeName String CODEC(ZSTD(1)),
    ScopeVersion String CODEC(ZSTD(1)),
    ScopeAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    ScopeDroppedAttrCount UInt32 CODEC(ZSTD(1)),
    ScopeSchemaUrl String CODEC(ZSTD(1)),
    ServiceName LowCardinality(String) CODEC(ZSTD(1)),
    MetricName String CODEC(ZSTD(1)),
    MetricDescription String CODEC(ZSTD(1)),
    MetricUnit String CODEC(ZSTD(1)),
    Attributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    StartTimeUnix DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    TimeUnix DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    Value Float64 CODEC(ZSTD(1)),
    Flags UInt32 CODEC(ZSTD(1)),
    INDEX idx_res_attr_key mapKeys(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_scope_attr_key mapKeys(ScopeAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_scope_attr_value mapValues(ScopeAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_attr_key mapKeys(Attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_attr_value mapValues(Attributes) TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toDate(TimeUnix)
ORDER BY (ServiceName, MetricName, Attributes, toUnixTimestamp64Nano(TimeUnix))
TTL toDateTime(TimeUnix) + toIntervalDay(30)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1;

-- OTEL METRICS SUM
CREATE TABLE IF NOT EXISTS ${DATABASE}.otel_metrics_sum
(
    ResourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    ResourceSchemaUrl String CODEC(ZSTD(1)),
    ScopeName String CODEC(ZSTD(1)),
    ScopeVersion String CODEC(ZSTD(1)),
    ScopeAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    ScopeDroppedAttrCount UInt32 CODEC(ZSTD(1)),
    ScopeSchemaUrl String CODEC(ZSTD(1)),
    ServiceName LowCardinality(String) CODEC(ZSTD(1)),
    MetricName String CODEC(ZSTD(1)),
    MetricDescription String CODEC(ZSTD(1)),
    MetricUnit String CODEC(ZSTD(1)),
    Attributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    StartTimeUnix DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    TimeUnix DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    Value Float64 CODEC(ZSTD(1)),
    Flags UInt32 CODEC(ZSTD(1)),
    AggregationTemporality Int32 CODEC(ZSTD(1)),
    IsMonotonic Bool CODEC(Delta(1), ZSTD(1)),
    INDEX idx_res_attr_key mapKeys(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_scope_attr_key mapKeys(ScopeAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_scope_attr_value mapValues(ScopeAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_attr_key mapKeys(Attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_attr_value mapValues(Attributes) TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toDate(TimeUnix)
ORDER BY (ServiceName, MetricName, Attributes, toUnixTimestamp64Nano(TimeUnix))
TTL toDateTime(TimeUnix) + toIntervalDay(30)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1;
EOFSQL
)

if [ "$USE_KUBECTL" = true ]; then
    # Find a ClickHouse pod
    CH_POD=$(kubectl get pods -n clickhouse -l app=clickhouse -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$CH_POD" ]; then
        # Try alternative label
        CH_POD=$(kubectl get pods -n clickhouse -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | head -1 || echo "")
    fi
    
    if [ -z "$CH_POD" ]; then
        echo "❌ Could not find ClickHouse pod in 'clickhouse' namespace"
        echo "   Please provide ClickHouse pod name or endpoint"
        exit 1
    fi
    
    echo "📦 Using ClickHouse pod: $CH_POD"
    echo ""
    echo "Executing SQL..."
    echo "$SQL" | kubectl exec -i -n clickhouse $CH_POD -- clickhouse-client \
        --host="${CLICKHOUSE_ENDPOINT%%:*}" \
        --port="${CLICKHOUSE_ENDPOINT##*:}" \
        --user="$CLICKHOUSE_USER" \
        --password="$CLICKHOUSE_PASSWORD" \
        --database="$DATABASE" \
        --multiquery
else
    echo "Executing SQL..."
    echo "$SQL" | clickhouse-client \
        --host="${CLICKHOUSE_ENDPOINT%%:*}" \
        --port="${CLICKHOUSE_ENDPOINT##*:}" \
        --user="$CLICKHOUSE_USER" \
        --password="$CLICKHOUSE_PASSWORD" \
        --database="$DATABASE" \
        --multiquery
fi

echo ""
echo "✅ Metrics tables created successfully!"
echo ""
echo "Created tables:"
echo "  - ${DATABASE}.otel_metrics_gauge"
echo "  - ${DATABASE}.otel_metrics_sum"
echo ""
echo "You can verify with:"
echo "  SHOW TABLES FROM ${DATABASE};"
