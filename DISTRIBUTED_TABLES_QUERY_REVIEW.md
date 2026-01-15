# ClickHouse DISTRIBUTED Tables Query Review

## Executive Summary

This document reviews the codebase to verify that all queries are compatible with the DISTRIBUTED table schema changes. The review covers:
- Schema definitions
- SELECT query patterns
- INSERT operations
- Materialized views
- Query optimization considerations

## 1. Schema Review ✅

### DISTRIBUTED Table Definitions
Located in `scripts/01_init_cluster.sql`:

**Tables Created:**
- `tracefox.otel_logs` → DISTRIBUTED over `otel_logs_local`
- `tracefox.otel_traces` → DISTRIBUTED over `otel_traces_local`
- `tracefox.tracefox_sessions` → DISTRIBUTED over `tracefox_sessions_local`

**Sharding Key:** All tables use `rand()` as the sharding key, which provides:
- ✅ Even data distribution across shards
- ⚠️ No query locality optimization (queries must scan all shards)
- ⚠️ Potential for suboptimal performance on filtered queries

**Local Tables:** Use `ReplicatedMergeTree` engine, which is correct for cluster setup.

## 2. SELECT Query Compatibility ✅

### Query Construction
All queries use the `tableExpr()` function from `hyperdx/packages/common-utils/src/clickhouse/index.ts`:

```typescript
export const tableExpr = ({
  database,
  table,
}: {
  database: string;
  table: string;
}) => {
  return chSql`${{ Identifier: database }}.${{ Identifier: table }}`;
};
```

This correctly constructs `database.table` references, which work seamlessly with DISTRIBUTED tables.

### Query Patterns Verified

1. **Metadata Queries** (`hyperdx/packages/common-utils/src/core/metadata.ts`):
   - ✅ `DESCRIBE` queries work with DISTRIBUTED tables
   - ✅ `SELECT DISTINCT` for keys/values works correctly
   - ✅ Map key/value extraction queries are compatible

2. **Chart/Visualization Queries** (`hyperdx/packages/common-utils/src/core/renderChartConfig.ts`):
   - ✅ `SELECT` with aggregations (count, sum, avg, min, max)
   - ✅ `GROUP BY` clauses
   - ✅ `WHERE` filters
   - ✅ `ORDER BY` and `LIMIT`
   - ✅ Time-based bucketing queries

3. **Test Queries** (smoke tests):
   - ✅ All test queries reference `otel_logs` (distributed table name)
   - ✅ No direct references to `*_local` tables found

### No Direct Local Table References Found ✅
Searched for patterns like `otel_logs_local`, `otel_traces_local`, `tracefox_sessions_local`:
- Only found in schema definition file (`01_init_cluster.sql`)
- No application code directly references local tables

## 3. INSERT Operations ✅

### INSERT Compatibility
ClickHouse DISTRIBUTED tables automatically route INSERTs to the appropriate local tables based on the sharding key. The codebase uses:

1. **Bulk Insert Functions** (`hyperdx/packages/api/src/fixtures.ts`):
   - `bulkInsertData()` - Uses `client.insert()` with table name
   - `bulkInsertLogs()` - Inserts to `${DEFAULT_DATABASE}.${DEFAULT_LOGS_TABLE}`
   - `bulkInsertMetricsGauge()` - Inserts to metrics tables

2. **Table References:**
   - All INSERT operations use the distributed table names (e.g., `otel_logs`, `otel_traces`)
   - ✅ No direct INSERTs to `*_local` tables

### INSERT Best Practices
- ✅ Using distributed table names (correct)
- ✅ Batch inserts supported
- ⚠️ Consider using `async_insert=1` setting for better performance with distributed tables

## 4. Materialized Views ⚠️

### Current Implementation
Located in `hyperdx/packages/app/src/hdxMTViews.ts`:

**Issue Found:**
- Materialized views use `AggregatingMergeTree` engine
- No cluster support detected (despite `walkthrough.md` mentioning it)
- Materialized views are created in `hyperdx` database
- No `ON CLUSTER` clause in DDL generation

**Recommendations:**
1. For cluster deployments, materialized views should:
   - Use `ReplicatedAggregatingMergeTree` for the data table
   - Include `ON CLUSTER '{cluster}'` in CREATE statements
   - Create a DISTRIBUTED table over the replicated local tables

2. Current code structure:
   ```typescript
   ENGINE = AggregatingMergeTree  // Should be ReplicatedAggregatingMergeTree in cluster
   ```

**Action Required:**
- Update `buildMTViewDataTableDDL()` to detect cluster mode
- Add `ON CLUSTER` support to materialized view DDL
- Consider creating DISTRIBUTED tables for materialized view data tables

## 5. Query Optimization Considerations

### Sharding Key Analysis

**Current:** `rand()` sharding key

**Pros:**
- Even data distribution
- Simple to implement
- Works for all query patterns

**Cons:**
- No query locality (all shards must be queried)
- Cannot optimize queries that filter by specific values
- Higher network overhead for distributed queries

**Alternative Sharding Keys to Consider:**
1. **By ServiceName:** `ServiceName` or `cityHash64(ServiceName)`
   - Better for queries filtering by service
   - May cause uneven distribution if services have different data volumes

2. **By Timestamp:** `toYYYYMM(TimestampTime)` or `toDate(TimestampTime)`
   - Better for time-range queries
   - Allows partition pruning at shard level

3. **By TraceId:** `cityHash64(TraceId)`
   - Better for trace-specific queries
   - Ensures all spans of a trace are on same shard (if using same sharding key)

### GLOBAL IN Optimization
**Status:** ✅ No `GLOBAL IN` or `GLOBAL NOT IN` queries found

These are typically needed for distributed subqueries, but the current query patterns don't require them.

### ClickHouse Settings
**Current Settings:**
- `distributed_ddl/path` configured ✅
- `wait_end_of_query: 1` used in some operations ✅

**Recommended Additional Settings:**
- `distributed_aggregation_memory_efficient: 1` - For better aggregation performance
- `max_threads: 0` - Use all available threads
- `max_distributed_connections: 1024` - Increase for better parallelism

## 6. Potential Issues & Recommendations

### ✅ Issue 1: Materialized Views Not Cluster-Aware - FIXED
**Severity:** Medium
**Impact:** Materialized views won't work correctly in cluster mode
**Status:** ✅ **FIXED** - Updated `hdxMTViews.ts` to support cluster mode

**Changes Made:**
- Added `ClusterConfig` interface for cluster configuration
- Updated `buildMTViewDataTableDDL()` to use `ReplicatedAggregatingMergeTree` when cluster mode is enabled
- Added `ON CLUSTER` clause support to both table and view DDL generation
- Added automatic generation of DISTRIBUTED table DDL for materialized views in cluster mode
- Cluster mode can be enabled via `CLICKHOUSE_CLUSTER` environment variable or passed as parameter

### ⚠️ Issue 2: Sharding Key May Not Be Optimal
**Severity:** Low
**Impact:** Queries may be slower than necessary, but will still work
**Fix:** Consider changing sharding key based on query patterns

### ✅ Issue 3: No Direct Local Table References
**Status:** Good - All queries use distributed table names

### ✅ Issue 4: INSERT Operations Compatible
**Status:** Good - All INSERTs use distributed table names

## 7. Testing Recommendations

1. **Verify Distributed Query Execution:**
   ```sql
   -- Check query is distributed
   EXPLAIN SELECT count() FROM tracefox.otel_logs;
   -- Should show queries to multiple shards
   ```

2. **Test INSERT Distribution:**
   ```sql
   -- Insert test data
   INSERT INTO tracefox.otel_logs VALUES (...);
   
   -- Check data distribution across shards
   SELECT count() FROM tracefox.otel_logs_local;  -- On each shard
   ```

3. **Performance Testing:**
   - Run typical query patterns
   - Monitor query execution time
   - Check network traffic between shards
   - Verify aggregation correctness

4. **Materialized View Testing:**
   - Create a materialized view
   - Verify it works with distributed source tables
   - Test query performance

## 8. Conclusion

### ✅ What's Working:
- DISTRIBUTED table schema is correctly defined
- All SELECT queries use distributed table names
- All INSERT operations use distributed table names
- Query construction code is compatible
- No direct references to local tables in application code

### ⚠️ What Needs Attention:
- Materialized views need cluster support
- Consider optimizing sharding key based on query patterns
- Add distributed query optimization settings

### 📋 Action Items:
1. ✅ **High Priority:** Update materialized views to support cluster mode - **COMPLETED**
2. **Medium Priority:** Review and potentially optimize sharding key
3. **Low Priority:** Add distributed query optimization settings

## 9. Implementation Details

### Materialized Views Cluster Support

The materialized views have been updated to support ClickHouse clusters:

**Configuration:**
- Set `CLICKHOUSE_CLUSTER` environment variable to the cluster name (e.g., `tracefox` or `{cluster}`)
- Or pass `clusterConfig` parameter to `buildMTViewSelectQuery()`

**What Changed:**
1. **Data Tables:** Use `ReplicatedAggregatingMergeTree` instead of `AggregatingMergeTree` in cluster mode
2. **DDL Generation:** All CREATE statements include `ON CLUSTER '{cluster}'` when cluster mode is enabled
3. **Distributed Tables:** Automatically generates DISTRIBUTED table DDL for materialized views
4. **ZooKeeper Path:** Uses proper ZooKeeper path pattern: `/clickhouse/tables/{shard}/hyperdx/{table_name}`

**Usage Example:**
```typescript
// With environment variable
process.env.CLICKHOUSE_CLUSTER = 'tracefox';
const result = await buildMTViewSelectQuery(chartConfig);

// Or with explicit config
const result = await buildMTViewSelectQuery(chartConfig, undefined, {
  enabled: true,
  clusterName: 'tracefox'
});

// Result includes:
// - dataTableDDL: CREATE TABLE ... ON CLUSTER ... ENGINE = ReplicatedAggregatingMergeTree(...)
// - mtViewDDL: CREATE MATERIALIZED VIEW ... ON CLUSTER ...
// - distributedTableDDL: CREATE TABLE ... ON CLUSTER ... ENGINE = Distributed(...)
```

## References

- ClickHouse DISTRIBUTED Engine: https://clickhouse.com/docs/en/engines/table-engines/special/distributed
- ClickHouse Sharding Best Practices: https://clickhouse.com/docs/en/guides/best-practices/sharding
- ClickHouse Materialized Views: https://clickhouse.com/docs/en/sql-reference/statements/create/view#materialized-view
