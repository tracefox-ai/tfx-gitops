# clickhouse

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 25.7](https://img.shields.io/badge/AppVersion-25.7-informational?style=flat-square)

A Helm chart for ClickHouse cluster using Altinity ClickHouse Operator

**Homepage:** <https://clickhouse.com>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| TraceFox Team | <support@tracefox.ai> |  |

## Source Code

* <https://github.com/tracefox-ai/tfx-gitops>
* <https://github.com/Altinity/clickhouse-operator>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clickhouse.cluster.name | string | `"tracefox"` |  |
| clickhouse.cluster.replicasCount | int | `2` |  |
| clickhouse.cluster.shardsCount | int | `2` |  |
| clickhouse.configuration.profiles.default.allow_experimental_analyzer | int | `1` |  |
| clickhouse.configuration.profiles.default.load_balancing | string | `"random"` |  |
| clickhouse.configuration.profiles.default.log_queries | int | `1` |  |
| clickhouse.configuration.profiles.default.max_memory_usage | int | `1000000000` |  |
| clickhouse.configuration.profiles.default.use_uncompressed_cache | int | `0` |  |
| clickhouse.configuration.quotas.default.interval.duration | int | `3600` |  |
| clickhouse.configuration.quotas.default.interval.errors | int | `0` |  |
| clickhouse.configuration.quotas.default.interval.execution_time | int | `0` |  |
| clickhouse.configuration.quotas.default.interval.queries | int | `0` |  |
| clickhouse.configuration.quotas.default.interval.read_rows | int | `0` |  |
| clickhouse.configuration.quotas.default.interval.result_rows | int | `0` |  |
| clickhouse.configuration.settings.asynchronous_metric_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.asynchronous_metric_log/flush_interval_milliseconds | string | `"7000"` |  |
| clickhouse.configuration.settings.asynchronous_metric_log/table | string | `"asynchronous_metric_log"` |  |
| clickhouse.configuration.settings.default_database | string | `"default"` |  |
| clickhouse.configuration.settings.default_profile | string | `"default"` |  |
| clickhouse.configuration.settings.distributed_ddl/path | string | `"/clickhouse/task_queue/ddl"` |  |
| clickhouse.configuration.settings.format_schema_path | string | `"/var/lib/clickhouse/format_schemas/"` |  |
| clickhouse.configuration.settings.http_port | string | `"8123"` |  |
| clickhouse.configuration.settings.interserver_http_port | string | `"9009"` |  |
| clickhouse.configuration.settings.listen_host | string | `"0.0.0.0"` |  |
| clickhouse.configuration.settings.logger/console | string | `"true"` |  |
| clickhouse.configuration.settings.logger/level | string | `"information"` |  |
| clickhouse.configuration.settings.mark_cache_size | string | `"5368709120"` |  |
| clickhouse.configuration.settings.max_concurrent_queries | string | `"100"` |  |
| clickhouse.configuration.settings.metric_log/collect_interval_milliseconds | string | `"1000"` |  |
| clickhouse.configuration.settings.metric_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.metric_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.metric_log/table | string | `"metric_log"` |  |
| clickhouse.configuration.settings.opentelemetry_span_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.opentelemetry_span_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.opentelemetry_span_log/table | string | `"opentelemetry_span_log"` |  |
| clickhouse.configuration.settings.part_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.part_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.part_log/table | string | `"part_log"` |  |
| clickhouse.configuration.settings.path | string | `"/var/lib/clickhouse/"` |  |
| clickhouse.configuration.settings.prometheus/asynchronous_metrics | string | `"true"` |  |
| clickhouse.configuration.settings.prometheus/endpoint | string | `"/metrics"` |  |
| clickhouse.configuration.settings.prometheus/events | string | `"true"` |  |
| clickhouse.configuration.settings.prometheus/metrics | string | `"true"` |  |
| clickhouse.configuration.settings.prometheus/port | string | `"8001"` |  |
| clickhouse.configuration.settings.prometheus/status_info | string | `"false"` |  |
| clickhouse.configuration.settings.query_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.query_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.query_log/table | string | `"query_log"` |  |
| clickhouse.configuration.settings.query_thread_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.query_thread_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.query_thread_log/table | string | `"query_thread_log"` |  |
| clickhouse.configuration.settings.query_views_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.query_views_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.query_views_log/table | string | `"query_views_log"` |  |
| clickhouse.configuration.settings.tcp_port | string | `"9000"` |  |
| clickhouse.configuration.settings.timezone | string | `"UTC"` |  |
| clickhouse.configuration.settings.tmp_path | string | `"/var/lib/clickhouse/tmp/"` |  |
| clickhouse.configuration.settings.trace_log/database | string | `"system"` |  |
| clickhouse.configuration.settings.trace_log/flush_interval_milliseconds | string | `"7500"` |  |
| clickhouse.configuration.settings.trace_log/table | string | `"trace_log"` |  |
| clickhouse.configuration.settings.uncompressed_cache_size | string | `"8589934592"` |  |
| clickhouse.configuration.settings.user_files_path | string | `"/var/lib/clickhouse/user_files/"` |  |
| clickhouse.configuration.settings.users_config | string | `"users.xml"` |  |
| clickhouse.enabled | bool | `true` |  |
| clickhouse.env | list | `[]` |  |
| clickhouse.image.pullPolicy | string | `"IfNotPresent"` |  |
| clickhouse.image.repository | string | `"clickhouse/clickhouse-server"` |  |
| clickhouse.image.tag | string | `"25.7-alpine"` |  |
| clickhouse.name | string | `"clickhouse"` |  |
| clickhouse.podAnnotations."prometheus.io/path" | string | `"/metrics"` |  |
| clickhouse.podAnnotations."prometheus.io/port" | string | `"8001"` |  |
| clickhouse.podAnnotations."prometheus.io/scrape" | string | `"true"` |  |
| clickhouse.resources.limits.cpu | string | `"1000m"` |  |
| clickhouse.resources.limits.memory | string | `"2Gi"` |  |
| clickhouse.resources.requests.cpu | string | `"500m"` |  |
| clickhouse.resources.requests.memory | string | `"512Mi"` |  |
| clickhouse.service.ports[0].name | string | `"http"` |  |
| clickhouse.service.ports[0].port | int | `8123` |  |
| clickhouse.service.ports[1].name | string | `"tcp"` |  |
| clickhouse.service.ports[1].port | int | `9000` |  |
| clickhouse.service.type | string | `"LoadBalancer"` |  |
| clickhouse.storage.accessModes[0] | string | `"ReadWriteOnce"` |  |
| clickhouse.storage.class | string | `"hostpath"` |  |
| clickhouse.storage.size | string | `"5Gi"` |  |
| clickhouse.templates.dataVolumeClaimTemplate | string | `"clickhouse-data"` |  |
| clickhouse.templates.podTemplate | string | `"clickhouse-pod"` |  |
| clickhouse.templates.serviceTemplate | string | `"clickhouse-service"` |  |
| clickhouse.users.admin.networks.ip | string | `"::/0"` |  |
| clickhouse.users.admin.password | string | `"admin"` |  |
| clickhouse.users.admin.profile | string | `"default"` |  |
| clickhouse.users.admin.username | string | `"admin"` |  |
| clickhouse.zookeeper.enabled | bool | `true` |  |
| externalSecrets.adminPasswordPath | string | `"clickhouse/admin-password"` |  |
| externalSecrets.enabled | bool | `false` |  |
| externalSecrets.secretStore | string | `"aws-secrets-manager"` |  |
| externalSecrets.secretStoreKind | string | `"SecretStore"` |  |
| fullnameOverride | string | `""` |  |
| keeper.annotations."prometheus.io/port" | string | `"7000"` |  |
| keeper.annotations."prometheus.io/scrape" | string | `"true"` |  |
| keeper.clusterName | string | `"tracefox"` |  |
| keeper.configuration.settings.keeper_server/coordination_settings/raft_logs_level | string | `"information"` |  |
| keeper.configuration.settings.keeper_server/four_letter_word_white_list | string | `"*"` |  |
| keeper.configuration.settings.listen_host | string | `"0.0.0.0"` |  |
| keeper.configuration.settings.logger/console | string | `"true"` |  |
| keeper.configuration.settings.logger/level | string | `"trace"` |  |
| keeper.configuration.settings.prometheus/asynchronous_metrics | string | `"true"` |  |
| keeper.configuration.settings.prometheus/endpoint | string | `"/metrics"` |  |
| keeper.configuration.settings.prometheus/events | string | `"true"` |  |
| keeper.configuration.settings.prometheus/metrics | string | `"true"` |  |
| keeper.configuration.settings.prometheus/port | string | `"7000"` |  |
| keeper.configuration.settings.prometheus/status_info | string | `"false"` |  |
| keeper.enabled | bool | `true` |  |
| keeper.image.pullPolicy | string | `"IfNotPresent"` |  |
| keeper.image.repository | string | `"clickhouse/clickhouse-keeper"` |  |
| keeper.image.tag | string | `"24.3-alpine"` |  |
| keeper.name | string | `"clickhouse-keeper"` |  |
| keeper.podAnnotations."prometheus.io/port" | string | `"7000"` |  |
| keeper.podAnnotations."prometheus.io/scrape" | string | `"true"` |  |
| keeper.replicasCount | int | `3` |  |
| keeper.resources.limits.cpu | string | `"2"` |  |
| keeper.resources.limits.memory | string | `"4Gi"` |  |
| keeper.resources.requests.cpu | string | `"1"` |  |
| keeper.resources.requests.memory | string | `"256M"` |  |
| keeper.securityContext.fsGroup | int | `101` |  |
| keeper.storage.accessModes[0] | string | `"ReadWriteOnce"` |  |
| keeper.storage.class | string | `"hostpath"` |  |
| keeper.storage.size | string | `"10Gi"` |  |
| keeper.templates.dataVolumeClaimTemplate | string | `"both-paths"` |  |
| keeper.templates.podTemplate | string | `"clickhouse-keeper-pod"` |  |
| keeper.zookeeperPort | int | `2181` |  |
| nameOverride | string | `""` |  |
| security.generateRandomPassword | bool | `false` |  |
| security.passwordLength | int | `32` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
