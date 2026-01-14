# ClickHouse Distributed Mode Implementation

## Overview

This document explains the implementation of ClickHouse distributed mode in HyperDX. The changes enable the frontend to query ClickHouse through distributed tables, simulating a multi-shard cluster environment even with a single ClickHouse instance.

## Why Distributed Mode?

### Problem Statement

In a production ClickHouse cluster setup:
- Data is distributed across multiple shards (servers)
- Queries need to aggregate data from all shards
- Certain operations (like `IN` and `JOIN`) require special handling in distributed queries
- The frontend needs to be cluster-aware to work correctly

### Solution

We implemented distributed mode to:
1. **Simulate a cluster environment** for development and testing
2. **Prepare the frontend** for production cluster deployments
3. **Ensure query correctness** with proper GLOBAL operation handling
4. **Maintain compatibility** with both single-instance and cluster setups

## Architecture

### ClickHouse Distributed Tables Concept

In ClickHouse, there are two types of tables:

1. **Local Tables** (e.g., `otel_logs`)
   - Store actual data on each shard
   - Each shard has its own local table with a subset of data
   - Data is sharded based on a sharding key

2. **Distributed Tables** (e.g., `otel_logs_distributed`)
   - Virtual tables that don't store data
   - Act as proxies that route queries to local tables across all shards
   - Aggregate results from all shards when queried

### Data Flow

```
┌─────────────────┐
│  OTel Collector │
└────────┬────────┘
         │ Writes data
         ▼
┌─────────────────────────────┐
│  Local Tables (Shard 1)     │
│  - otel_logs                │
│  - otel_traces              │
│  - hyperdx_sessions         │
│  (Actual data storage)      │
└─────────────────────────────┘
         ▲
         │ Queries routed through
         │
┌─────────────────────────────┐
│  Distributed Tables         │
│  - otel_logs_distributed    │
│  - otel_traces_distributed   │
│  - hyperdx_sessions_dist    │
│  (Query routing layer)      │
└─────────────────────────────┘
         ▲
         │ Frontend queries
         │
┌─────────────────┐
│  HyperDX        │
│  Frontend       │
└─────────────────┘
```

### With Multiple Shards (Future)

```
Shard 1:                    Shard 2:
┌──────────────┐           ┌──────────────┐
│ otel_logs    │           │ otel_logs    │
│ (rows 1,3,5) │           │ (rows 2,4,6) │
└──────────────┘           └──────────────┘
       ▲                           ▲
       │                           │
       └───────────┬───────────────┘
                   │
         ┌─────────────────┐
         │ otel_logs_      │
         │ distributed     │
         │ (aggregates     │
         │  all shards)    │
         └─────────────────┘
```

## Changes Made

### 1. Database Initialization (`docker/clickhouse/local/init-db.sh`)

**What Changed:**
- Added distributed table creation at the end of the initialization script
- Creates three distributed tables that point to local tables via the cluster

**Code Added:**
```bash
# Create distributed tables that point to local tables
CREATE TABLE IF NOT EXISTS ${DATABASE}.otel_logs_distributed
ENGINE = Distributed('hdx_cluster', ${DATABASE}, otel_logs, rand());

CREATE TABLE IF NOT EXISTS ${DATABASE}.otel_traces_distributed
ENGINE = Distributed('hdx_cluster', ${DATABASE}, otel_traces, rand());

CREATE TABLE IF NOT EXISTS ${DATABASE}.hyperdx_sessions_distributed
ENGINE = Distributed('hdx_cluster', ${DATABASE}, hyperdx_sessions, rand());
```

**Why:**
- **Distributed Engine**: The `Distributed` engine creates a virtual table that routes queries to local tables across the cluster
- **Cluster Reference**: `'hdx_cluster'` references the cluster defined in `config.xml`
- **Sharding Key**: `rand()` distributes data randomly across shards (even distribution)
- **Automatic Creation**: Tables are created on every startup, ensuring they always exist

**How It Works:**
- When you query `otel_logs_distributed`, ClickHouse:
  1. Identifies all shards in `hdx_cluster`
  2. Sends the query to each shard's local `otel_logs` table
  3. Aggregates results from all shards
  4. Returns the combined result set

### 2. Query Generation (`packages/common-utils/src/core/renderChartConfig.ts`)

**What Changed:**
- Added `getDistributedTableName()` function to convert table names
- Modified `renderFrom()` to automatically use distributed table names

**Code Added:**
```typescript
function getDistributedTableName(tableName: string): string {
  // If already a distributed table, return as-is
  if (tableName.endsWith('_distributed')) {
    return tableName;
  }

  // Map known table names to their distributed equivalents
  const distributedTableMap: Record<string, string> = {
    otel_logs: 'otel_logs_distributed',
    otel_traces: 'otel_traces_distributed',
    hyperdx_sessions: 'hyperdx_sessions_distributed',
  };

  // Return distributed table name if mapped, otherwise append _distributed
  return distributedTableMap[tableName] || `${tableName}_distributed`;
}

function renderFrom({ from }: { from: ChartConfigWithDateRange['from'] }): ChSql {
  const tableName = getDistributedTableName(from.tableName);
  // ... rest of the function
}
```

**Why:**
- **Transparent Conversion**: Frontend code doesn't need to change - it still references `otel_logs`, but queries use `otel_logs_distributed`
- **Automatic Routing**: All queries automatically go through distributed tables
- **Backward Compatible**: If a table name already ends with `_distributed`, it's used as-is
- **Future Proof**: Unknown tables get `_distributed` appended automatically

**Example:**
```typescript
// Frontend code still uses:
from: { tableName: 'otel_logs' }

// But the generated SQL becomes:
SELECT * FROM default.otel_logs_distributed
```

### 3. ClickHouse Settings (`packages/app/src/hooks/useMetadata.tsx`)

**What Changed:**
- Always sets `prefer_global_in_and_join = 1` in ClickHouse query settings

**Code Added:**
```typescript
// Always enable GLOBAL IN/JOIN for distributed queries
// Tables are always distributed, so we need GLOBAL prefix for IN/JOIN operations
settings.prefer_global_in_and_join = 1;
```

**Why:**
- **GLOBAL Operations**: In distributed queries, `IN` and `JOIN` operations need special handling
- **Query Correctness**: Without `GLOBAL`, subqueries execute on each shard independently, which can lead to incorrect results
- **Automatic Conversion**: This setting makes ClickHouse automatically convert:
  - `IN` → `GLOBAL IN`
  - `JOIN` → `GLOBAL JOIN`

**Example:**
```sql
-- Without GLOBAL (incorrect in distributed mode):
SELECT * FROM otel_logs_distributed 
WHERE TraceId IN (SELECT TraceId FROM other_table)
-- This executes the subquery on each shard separately

-- With prefer_global_in_and_join = 1 (correct):
SELECT * FROM otel_logs_distributed 
WHERE TraceId GLOBAL IN (SELECT TraceId FROM other_table)
-- This executes the subquery once and uses the result on all shards
```

**Why GLOBAL is Needed:**
- **Subquery Execution**: `GLOBAL IN` executes the subquery on the initiator node first
- **Result Distribution**: The result is then sent to all shards for filtering
- **Consistency**: Ensures all shards use the same subquery result

### 4. Documentation (`docker-compose.dev.yml`)

**What Changed:**
- Added a comment explaining distributed table creation

**Why:**
- **Clarity**: Documents that distributed tables are always created
- **Maintenance**: Helps future developers understand the setup

## How It Works End-to-End

### 1. Startup Sequence

```
1. Docker Compose starts ClickHouse container
2. ClickHouse runs init-db.sh
3. Local tables created: otel_logs, otel_traces, hyperdx_sessions
4. Distributed tables created: *_distributed versions
5. System ready for data ingestion and queries
```

### 2. Data Ingestion

```
1. OTel Collector receives telemetry data
2. Collector writes to LOCAL tables (otel_logs, otel_traces)
3. Data is stored on the shard(s)
4. No data goes to distributed tables (they're just views)
```

### 3. Query Execution

```
1. Frontend generates query with table name: "otel_logs"
2. renderChartConfig converts to: "otel_logs_distributed"
3. Query sent to ClickHouse with prefer_global_in_and_join = 1
4. ClickHouse routes query to all shards via distributed table
5. Each shard queries its local otel_logs table
6. Results aggregated and returned to frontend
```

## Current Configuration

### Cluster Setup (`docker/clickhouse/local/config.xml`)

Currently configured with a single shard:
```xml
<remote_servers>
    <hdx_cluster>
        <shard>
            <replica>
                <host>ch-server</host>
                <port>9000</port>
            </replica>
        </shard>
    </hdx_cluster>
</remote_servers>
```

**Note:** With a single shard, the distributed table still works but only routes to one local table. This simulates cluster behavior for development.

### Adding More Shards (Future)

To add more shards, update `config.xml`:
```xml
<remote_servers>
    <hdx_cluster>
        <shard>
            <replica><host>ch-server-1</host><port>9000</port></replica>
        </shard>
        <shard>
            <replica><host>ch-server-2</host><port>9000</port></replica>
        </shard>
    </hdx_cluster>
</remote_servers>
```

Then data will be distributed across both shards based on the `rand()` sharding key.

## Benefits

1. **Production Ready**: Frontend code works correctly with cluster deployments
2. **Query Correctness**: GLOBAL operations ensure accurate results in distributed queries
3. **Transparent**: No changes needed in frontend code - conversion is automatic
4. **Scalable**: Easy to add more shards by updating cluster configuration
5. **Testable**: Can test distributed query behavior with a single instance

## Important Notes

### Data Storage

- **Collector writes to LOCAL tables**: This is correct and optimal
- **Frontend queries DISTRIBUTED tables**: This routes queries across shards
- **Distributed tables don't store data**: They're just routing layers

### Performance Considerations

- **Writing to local tables**: Faster, less overhead
- **Writing to distributed tables**: Possible but adds routing overhead
- **Querying distributed tables**: Slightly slower due to aggregation, but necessary for cluster queries

### GLOBAL Operations

- **Always enabled**: `prefer_global_in_and_join = 1` is set for all queries
- **Required for correctness**: Without GLOBAL, distributed queries can return incorrect results
- **Automatic**: ClickHouse handles the conversion automatically

## Testing

To verify the setup works:

1. **Check distributed tables exist:**
   ```sql
   SHOW TABLES LIKE '%_distributed';
   ```

2. **Verify query routing:**
   ```sql
   -- This should route through distributed table
   SELECT count() FROM default.otel_logs_distributed;
   ```

3. **Check GLOBAL setting:**
   ```sql
   -- Should show prefer_global_in_and_join = 1
   SELECT * FROM system.settings WHERE name = 'prefer_global_in_and_join';
   ```

## Troubleshooting

### Issue: Queries fail with "Table doesn't exist"

**Solution:** Ensure `init-db.sh` ran successfully. Check ClickHouse logs for errors.

### Issue: Queries return incorrect results

**Solution:** Verify `prefer_global_in_and_join = 1` is set. Check `useMetadata.tsx` settings.

### Issue: Data not appearing in queries

**Solution:** 
- Verify collector is writing to LOCAL tables (otel_logs, not otel_logs_distributed)
- Check that distributed tables point to correct local tables
- Verify cluster configuration in `config.xml`

## Future Enhancements

1. **Multiple Shards**: Add more shards to the cluster configuration
2. **Replication**: Add replicas for high availability
3. **Custom Sharding**: Replace `rand()` with a more intelligent sharding key (e.g., by ServiceName)
4. **Monitoring**: Add metrics for distributed query performance

## References

- [ClickHouse Distributed Engine Documentation](https://clickhouse.com/docs/en/engines/table-engines/special/distributed)
- [ClickHouse GLOBAL IN/JOIN Documentation](https://clickhouse.com/docs/en/sql-reference/operators/in#select-global-in)
- [ClickHouse Cluster Setup Guide](https://clickhouse.com/docs/en/operations/cluster)
