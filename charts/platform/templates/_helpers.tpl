{{- define "platform.name" -}}
{{- default .Chart.Name .Values.global.platformName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "platform.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{- define "platform.labels" -}}
helm.sh/chart: {{ include "platform.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.global.platformName | quote }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "platform.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
platform.example.io/component: app
{{- end -}}

{{- define "platform.app.fullname" -}}
{{- .Values.app.name -}}
{{- end -}}

{{- define "platform.app.configmapName" -}}
{{- printf "%s-config" (include "platform.app.fullname" .) -}}
{{- end -}}

{{- define "platform.app.secretName" -}}
{{- printf "%s-secret" (include "platform.app.fullname" .) -}}
{{- end -}}

{{- define "platform.postgresql.fullname" -}}
{{- default "postgresql" .Values.postgresql.fullnameOverride -}}
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
{{- default "monitoring" .Values.monitoring.fullnameOverride -}}
{{- end -}}

{{- define "platform.monitoring.grafanaService" -}}
{{- printf "%s-grafana" (include "platform.monitoring.fullname" .) -}}
{{- end -}}

{{- define "platform.monitoring.alertmanagerService" -}}
{{- printf "%s-alertmanager" (include "platform.monitoring.fullname" .) -}}
{{- end -}}

{{- define "platform.loki.fullname" -}}
{{- default "loki" .Values.loki.fullnameOverride -}}
{{- end -}}
