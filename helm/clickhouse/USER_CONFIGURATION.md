# ClickHouse User Configuration

## Overview

This document explains how the ClickHouse Helm chart configures users to match the original `clickstack-original` setup when using the Altinity ClickHouse operator.

## Original Setup (clickstack-original)

The original setup used standalone ClickHouse containers with XML configuration files:
- `data/users.xml` - Defined user accounts
- `data/config.xml` - Defined server configuration

### Users Created

1. **`default`** - No password, localhost only
2. **`app`** - For HyperDX frontend
   - Password: `hyperdx` (configurable via `clickhouse.config.users.appUserPassword`)
   - Profile: `readonly`
   - Networks: Kubernetes cluster CIDRs + `.*\.svc\.cluster\.local$`
   - Grants:
     - `GRANT SHOW ON *.*`
     - `GRANT SELECT ON system.*`
     - `GRANT SELECT ON default.*`

3. **`otelcollector`** - For OTEL collector
   - Password: `otelcollectorpass` (configurable via `clickhouse.config.users.otelUserPassword`)
   - Profile: `default`
   - Networks: Kubernetes cluster CIDRs + `.*\.svc\.cluster\.local$`
   - Grants:
     - `GRANT SELECT,INSERT,CREATE,SHOW ON default.*`

## New Setup (Altinity Operator)

The Altinity operator uses Kubernetes Custom Resources (ClickHouseInstallation) instead of XML files. Users are defined in the CRD's `configuration.users` section.

### Changes Made

1. **Added `app` user** to `values.yaml`:
   - Password: `hyperdx` (matches original default)
   - Profile: `readonly` (requires readonly profile in configuration)
   - Networks: Kubernetes cluster CIDRs (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) + host_regexp for `.svc.cluster.local`
   - Grants: Same as original

2. **Added `otelcollector` user** to `values.yaml`:
   - Password: `otelcollectorpass` (matches original default)
   - Profile: `default`
   - Networks: Same as app user
   - Grants: Same as original

3. **Added `readonly` profile** to configuration:
   - `readonly: 2` (matches original)

4. **Updated `default` profile** to match original:
   - `max_memory_usage: 10000000000` (was 1000000000)
   - `load_balancing: in_order` (was random)

5. **Created secrets** for app and otelcollector users in `templates/secret.yaml`

6. **Updated `templates/clickhouse.yaml`** to include the new users in the ClickHouseInstallation CRD

## Verification

### Check if users are created:

```bash
# Get the ClickHouse installation
kubectl get chi -n <namespace>

# Describe the installation to see user configuration
kubectl describe chi <clickhouse-name> -n <namespace>

# Connect to ClickHouse and list users
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --query "SHOW USERS"

# Check specific user
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --query "SHOW CREATE USER app"
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --query "SHOW CREATE USER otelcollector"
```

### Test user authentication:

```bash
# Test app user (readonly)
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --user app --password hyperdx --query "SELECT 1"

# Test otelcollector user (write access)
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --user otelcollector --password otelcollectorpass --query "SELECT 1"

# Test app user can only SELECT (should work)
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --user app --password hyperdx --query "SELECT * FROM system.tables LIMIT 1"

# Test app user cannot INSERT (should fail)
kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --user app --password hyperdx --query "INSERT INTO system.metrics VALUES (1)" || echo "Expected: Readonly user cannot insert"
```

### Check secrets:

```bash
# List secrets
kubectl get secrets -n <namespace> | grep clickhouse

# Check app user secret
kubectl get secret <clickhouse-name>-app-secret -n <namespace> -o yaml

# Check otelcollector user secret
kubectl get secret <clickhouse-name>-otelcollector-secret -n <namespace> -o yaml
```

## Configuration Mapping

| Original (XML) | New (Altinity Operator) | Location |
|----------------|------------------------|----------|
| `users.xml` → `<app>` | `values.yaml` → `clickhouse.users.app` | `helm/clickhouse/values.yaml` |
| `users.xml` → `<otelcollector>` | `values.yaml` → `clickhouse.users.otelcollector` | `helm/clickhouse/values.yaml` |
| `config.xml` → `<profiles><readonly>` | `values.yaml` → `clickhouse.configuration.profiles.readonly` | `helm/clickhouse/values.yaml` |
| ConfigMap mounting | ClickHouseInstallation CRD | `helm/clickhouse/templates/clickhouse.yaml` |
| Secret creation | Kubernetes Secrets | `helm/clickhouse/templates/secret.yaml` |

## Troubleshooting

### Users not appearing

1. Check if the ClickHouseInstallation was updated:
   ```bash
   kubectl get chi <clickhouse-name> -n <namespace> -o yaml | grep -A 20 "users:"
   ```

2. Check operator logs:
   ```bash
   kubectl logs -n <operator-namespace> -l app=clickhouse-operator
   ```

3. Verify secrets exist:
   ```bash
   kubectl get secrets -n <namespace> | grep -E "(app|otelcollector)"
   ```

### Permission errors

1. Verify grants are applied:
   ```bash
   kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --query "SHOW GRANTS FOR app"
   ```

2. Check user profile:
   ```bash
   kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --query "SELECT name, profile FROM system.users WHERE name IN ('app', 'otelcollector')"
   ```

### Network access issues

1. Verify network restrictions:
   ```bash
   kubectl exec -it <clickhouse-pod-name> -n <namespace> -- clickhouse-client --query "SHOW CREATE USER app" | grep -A 10 networks
   ```

2. Test from within cluster:
   ```bash
   # From a pod in the same namespace
   curl -u app:hyperdx "http://<clickhouse-service>:8123/?query=SELECT 1"
   ```
