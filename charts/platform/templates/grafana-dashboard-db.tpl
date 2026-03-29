{{- define "platform.grafanaDashboardDb" -}}
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "unit": "ops"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "targets": [
        {
          "expr": "sum(rate(pg_stat_statements_rollup_calls_total{namespace=\"{{ .Release.Namespace }}\"}[$__rate_interval]))",
          "legendFormat": "queries/s",
          "refId": "A"
        }
      ],
      "title": "Queries Per Second",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "unit": "ms"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "legend": {
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "targets": [
        {
          "expr": "1000 * sum(rate(pg_stat_statements_rollup_total_exec_time_seconds_total{namespace=\"{{ .Release.Namespace }}\"}[$__rate_interval])) / clamp_min(sum(rate(pg_stat_statements_rollup_calls_total{namespace=\"{{ .Release.Namespace }}\"}[$__rate_interval])), 0.001)",
          "legendFormat": "mean latency",
          "refId": "A"
        }
      ],
      "title": "Mean Query Latency",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "unit": "cores"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "id": 3,
      "options": {
        "legend": {
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "targets": [
        {
          "expr": "sum by (pod) (node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{namespace=\"{{ .Release.Namespace }}\", pod=~\"{{ include "platform.postgresql.fullname" . }}.*\", container=\"postgresql\"})",
          "legendFormat": "{{`{{ pod }}`}}",
          "refId": "A"
        }
      ],
      "title": "DB Pod CPU Usage",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "id": 4,
      "options": {
        "legend": {
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "targets": [
        {
          "expr": "sum by (pod) (node_namespace_pod_container:container_memory_working_set_bytes{namespace=\"{{ .Release.Namespace }}\", pod=~\"{{ include "platform.postgresql.fullname" . }}.*\", container=\"postgresql\"})",
          "legendFormat": "{{`{{ pod }}`}}",
          "refId": "A"
        }
      ],
      "title": "DB Pod Memory Usage",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 39,
  "style": "dark",
  "tags": [
    "postgresql",
    "platform"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "browser",
  "title": "Platform PostgreSQL Overview",
  "uid": "platform-postgresql-overview",
  "version": 1,
  "weekStart": ""
}
{{- end -}}
