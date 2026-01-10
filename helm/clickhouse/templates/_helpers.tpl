{{/*
Expand the name of the chart.
*/}}
{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "clickhouse.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "clickhouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickhouse.labels" -}}
helm.sh/chart: {{ include "clickhouse.chart" . }}
{{ include "clickhouse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickhouse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Namespace name
Uses .Release.Namespace if provided, otherwise falls back to values or default
*/}}
{{- define "clickhouse.namespace" -}}
{{- if .Release.Namespace }}
{{- .Release.Namespace }}
{{- else if .Values.namespace.name }}
{{- .Values.namespace.name }}
{{- else }}
{{- "clickhouse" }}
{{- end }}
{{- end }}

{{/*
Get the admin secret name
*/}}
{{- define "clickhouse.adminSecretName" -}}
{{- if .Values.clickhouse.users.admin.existingSecret }}
{{- .Values.clickhouse.users.admin.existingSecret }}
{{- else }}
{{- printf "%s-admin-secret" .Values.clickhouse.name }}
{{- end }}
{{- end }}

{{/*
Get the admin secret key
*/}}
{{- define "clickhouse.adminSecretKey" -}}
{{- if .Values.clickhouse.users.admin.existingSecret }}
{{- .Values.clickhouse.users.admin.existingSecretKey | default "admin-password" }}
{{- else }}
{{- "admin-password" }}
{{- end }}
{{- end }}

{{/*
Get the default user secret name
*/}}
{{- define "clickhouse.defaultSecretName" -}}
{{- if .Values.clickhouse.users.default.existingSecret }}
{{- .Values.clickhouse.users.default.existingSecret }}
{{- else }}
{{- printf "%s-default-secret" .Values.clickhouse.name }}
{{- end }}
{{- end }}

{{/*
Get the default user secret key
*/}}
{{- define "clickhouse.defaultSecretKey" -}}
{{- if .Values.clickhouse.users.default.existingSecret }}
{{- .Values.clickhouse.users.default.existingSecretKey | default "default-password" }}
{{- else }}
{{- "default-password" }}
{{- end }}
{{- end }}

{{/*
Get the app user secret name
*/}}
{{- define "clickhouse.appSecretName" -}}
{{- if .Values.clickhouse.users.app.existingSecret }}
{{- .Values.clickhouse.users.app.existingSecret }}
{{- else }}
{{- printf "%s-app-secret" .Values.clickhouse.name }}
{{- end }}
{{- end }}

{{/*
Get the app user secret key
*/}}
{{- define "clickhouse.appSecretKey" -}}
{{- if .Values.clickhouse.users.app.existingSecret }}
{{- .Values.clickhouse.users.app.existingSecretKey | default "app-password" }}
{{- else }}
{{- "app-password" }}
{{- end }}
{{- end }}

{{/*
Get the otelcollector user secret name
*/}}
{{- define "clickhouse.otelcollectorSecretName" -}}
{{- if .Values.clickhouse.users.otelcollector.existingSecret }}
{{- .Values.clickhouse.users.otelcollector.existingSecret }}
{{- else }}
{{- printf "%s-otelcollector-secret" .Values.clickhouse.name }}
{{- end }}
{{- end }}

{{/*
Get the otelcollector user secret key
*/}}
{{- define "clickhouse.otelcollectorSecretKey" -}}
{{- if .Values.clickhouse.users.otelcollector.existingSecret }}
{{- .Values.clickhouse.users.otelcollector.existingSecretKey | default "otelcollector-password" }}
{{- else }}
{{- "otelcollector-password" }}
{{- end }}
{{- end }}

{{/*
ClickHouse image
*/}}
{{- define "clickhouse.image" -}}
{{- printf "%s:%s" .Values.clickhouse.image.repository .Values.clickhouse.image.tag }}
{{- end }}

{{/*
ClickHouse Keeper image
*/}}
{{- define "clickhouse.keeperImage" -}}
{{- printf "%s:%s" .Values.keeper.image.repository .Values.keeper.image.tag }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "clickhouse.validateValues" -}}
{{- if not .Values.clickhouse.cluster.name }}
{{- fail "clickhouse.cluster.name is required" }}
{{- end }}
{{- if not .Values.clickhouse.users.admin.username }}
{{- fail "clickhouse.users.admin.username is required" }}
{{- end }}
{{- end }}


