{{- define "platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "platform.partOf" -}}
{{- default (include "platform.name" .) .Values.global.platformName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "platform.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "platform.componentFullname" -}}
{{- $context := .context -}}
{{- $name := .name -}}
{{- if .override -}}
{{- .override | trunc 63 | trimSuffix "-" -}}
{{- else if contains $name $context.Release.Name -}}
{{- $context.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $context.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "platform.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{- define "platform.labels" -}}
helm.sh/chart: {{ include "platform.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "platform.partOf" . | quote }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "platform.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
platform.example.io/component: app
{{- end -}}

{{- define "platform.app.fullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" .Values.app.name "override" (default "" .Values.app.fullnameOverride)) -}}
{{- end -}}

{{- define "platform.app.configmapName" -}}
{{- printf "%s-config" (include "platform.app.fullname" .) -}}
{{- end -}}

{{- define "platform.app.secretName" -}}
{{- printf "%s-secret" (include "platform.app.fullname" .) -}}
{{- end -}}

{{- define "platform.dbInit.fullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "schema-init") -}}
{{- end -}}

{{- define "platform.postgresql.fullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "postgresql" "override" (default "" .Values.postgresql.fullnameOverride)) -}}
{{- end -}}

{{- define "platform.postgresql.serviceName" -}}
{{- include "platform.postgresql.fullname" . -}}
{{- end -}}

{{- define "platform.postgresql.secretName" -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- include "platform.postgresql.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "platform.postgresql.adminPasswordKey" -}}
{{- $secretKeys := dig "auth" "secretKeys" (dict) .Values.postgresql -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- default "postgres-password" (get $secretKeys "adminPasswordKey") -}}
{{- else -}}
postgres-password
{{- end -}}
{{- end -}}

{{- define "platform.postgresql.userPasswordKey" -}}
{{- $secretKeys := dig "auth" "secretKeys" (dict) .Values.postgresql -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- default "password" (get $secretKeys "userPasswordKey") -}}
{{- else -}}
password
{{- end -}}
{{- end -}}

{{- define "platform.monitoring.fullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "monitoring" "override" (default "" .Values.monitoring.fullnameOverride)) -}}
{{- end -}}

{{- define "platform.monitoring.grafanaFullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "grafana" "override" (default "" .Values.monitoring.grafana.fullnameOverride)) -}}
{{- end -}}

{{- define "platform.monitoring.grafanaService" -}}
{{- include "platform.monitoring.grafanaFullname" . -}}
{{- end -}}

{{- define "platform.monitoring.alertmanagerService" -}}
{{- printf "%s-alertmanager" (include "platform.monitoring.fullname" .) -}}
{{- end -}}

{{- define "platform.monitoring.prometheusService" -}}
{{- printf "%s-prometheus" (include "platform.monitoring.fullname" .) -}}
{{- end -}}

{{- define "platform.loki.fullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "loki" "override" (default "" .Values.loki.fullnameOverride)) -}}
{{- end -}}

{{- define "platform.loki.ruleConfigmapName" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "loki-slow-query-rules") -}}
{{- end -}}

{{- define "platform.alloy.fullname" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "alloy" "override" (default "" .Values.alloy.fullnameOverride)) -}}
{{- end -}}

{{- define "platform.grafanaDashboard.configmapName" -}}
{{- include "platform.componentFullname" (dict "context" . "name" "postgresql-dashboard") -}}
{{- end -}}

{{- define "platform.grafanaDashboard.uid" -}}
{{- printf "%s-postgresql-overview" .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- end -}}
