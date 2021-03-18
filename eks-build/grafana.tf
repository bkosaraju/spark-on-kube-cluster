locals {
  efsconfiggfn = <<PMSEFSCONFIG
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ${var.grafana-ns}-efs-sc
provisioner: efs.csi.aws.com
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${var.grafana-ns}-efs-claim
  namespace : ${var.grafana-ns}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${var.grafana-ns}-efs-sc
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${var.grafana-ns}-efs-pv
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${var.grafana-ns}-efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${aws_efs_file_system.cluster-efs.id}"
PMSEFSCONFIG

  grafanahelmopts = <<GFNHLMCNFG
adminUser: admin
adminPassword: ${var.grafana-admin-temp-password}
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/use-regex: "true"
  path: /
  hosts: 
    - grafana.${var.cluster-name}.${var.eks-hosted-dnszone}
grafana.ini:
  server:
    domain: grafana.${var.cluster-name}.${var.eks-hosted-dnszone}
    root_url: https://grafana.${var.cluster-name}.${var.eks-hosted-dnszone}/
  auth.generic_oauth:
    enabled: true
    name: OAuth
    client_id: ${aws_cognito_user_pool_client.grafana-pool-client.id}
    client_secret: ${aws_cognito_user_pool_client.grafana-pool-client.client_secret}
    scopes: openid profile email
    auth_url: https://${aws_cognito_user_pool_domain.pool-domain.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize
    token_url: https://${aws_cognito_user_pool_domain.pool-domain.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token
    api_url: https://${aws_cognito_user_pool_domain.pool-domain.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/userInfo
    allow_sign_up: true
    tls_skip_verify_insecure: true

ecurityContext:
    runAsUser: 0
    runAsGroup: 0
    fsGroup: 0

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: 'http://prometheus-server.${var.prometheus-ns}.svc.cluster.local'
        access: proxy
        isDefault: true
#service:
#  type: LoadBalancer
#  port: 80
#  targetPort: 3000
#  annotations: {}
#  labels: {}
#  portName: service
persistence:
  type: pvc
  enabled: true
  storageClassName: '${var.grafana-ns}-efs-sc'
  accessModes:
    - ReadWriteMany
  size: 100Gi
  existingClaim: '${var.grafana-ns}-efs-claim'
  subPath: 'data/${var.grafana-ns}'
initChownData:
  enabled: true
  image:
    repository: busybox
    tag: 1.31.1
    sha: ''
    pullPolicy: IfNotPresent
resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 2000m
    memory: 4Gi
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: kubernetes
        orgId: 1
        folder: kubernetes
        type: file
        disableDeletion: true
        editable: true
        options:
          path: /var/lib/grafana/dashboards/kubernetes
      - name: pipeline
        orgId: 1
        folder: pipeline
        type: file
        disableDeletion: true
        editable: true
        options:
          path: /var/lib/grafana/dashboards/pipeline
dashboardsConfigMaps:
   pipeline: "grafana-dashboards-configmap"
dashboards:
  kubernetes:
    kubernetes-cluster:
      gnetId: 7249
      datasource: Prometheus
    kubernetes-cm-1:
      gnetId: 3119
      datasource: Prometheus
    kubernetes-cm-2:
      gnetId: 6417
      datasource: Prometheus
    kubernetes-cm-3:
      gnetId: 8588
      datasource: Prometheus
    kubernetes-cm-4:
      gnetId: 11455
      datasource: Prometheus
    kubernetes-cm-5:
      gnetId: 315
      datasource: Prometheus
    kubernetes-cluster-monitoring-prometheus:
      gnetId: 1621
      datasource: Prometheus
GFNHLMCNFG


pipelinedashboard = <<PIPELINEDASHBOARD

apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    grafana_dashboard: "1"
  name: grafana-dashboards-configmap
  namespace: '${var.grafana-ns}'
data:
  pipeline-dashboard.json: |-
    {
      "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
      },
      "editable": true,
      "gnetId": null,
      "graphTooltip": 0,
      "id": 3,
      "links": [],
      "panels": [
    {
      "datasource": null,
      "description": "",
      "gridPos": {
        "h": 6,
        "w": 8,
        "x": 0,
        "y": 0
      },
      "hideTimeOverride": false,
      "id": 2,
      "interval": "6h",
      "options": {
        "fieldOptions": {
          "calcs": [
        "lastNotNull"
          ],
          "defaults": {
        "mappings": [],
        "max": 100,
        "thresholds": {
          "mode": "absolute",
          "steps": [
            {
              "color": "semi-dark-green",
              "value": null
            },
            {
              "color": "light-green",
              "value": 25
            },
            {
              "color": "dark-yellow",
              "value": 50
            },
            {
              "color": "#EF843C",
              "value": 75
            },
            {
              "color": "semi-dark-red",
              "value": 87.5
            }
          ]
        },
        "title": "$${__series.name}",
        "unit": "none"
          },
          "overrides": [],
          "values": true
        },
        "orientation": "auto",
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "6.6.2",
      "repeat": null,
      "targets": [
        {
          "expr": "(count(pipeline_job_duration_seconds == 0) - (count(pipeline_job_duration_seconds offset $__interval == 0) or (1-absent(pipeline_job_duration_seconds==NA)))) or 1- absent(pipeline_job_duration_seconds == 0)",
          "format": "time_series",
          "instant": true,
          "interval": "",
          "legendFormat": "Jobs",
          "refId": "B"
        },
        {
          "expr": "(count(pipeline_task_duration_seconds == 0) - (count(pipeline_task_duration_seconds offset $__interval == 0) or (1-absent(pipeline_task_duration_seconds==NA)))) or 1- absent(pipeline_task_duration_seconds == 0)",
          "format": "time_series",
          "instant": true,
          "legendFormat": "Tasks",
          "refId": "A"
        }
      ],
      "timeFrom": "6h",
      "timeShift": null,
      "title": "Running",
      "transparent": true,
      "type": "gauge"
    },
    {
      "datasource": null,
      "description": "",
      "gridPos": {
        "h": 6,
        "w": 7,
        "x": 8,
        "y": 0
      },
      "hideTimeOverride": false,
      "id": 15,
      "interval": "24h",
      "options": {
        "fieldOptions": {
          "calcs": [
        "lastNotNull"
          ],
          "defaults": {
        "mappings": [],
        "max": 100,
        "thresholds": {
          "mode": "absolute",
          "steps": [
            {
              "color": "semi-dark-orange",
              "value": null
            },
            {
              "color": "#EAB839",
              "value": 15
            },
            {
              "color": "semi-dark-blue",
              "value": 30
            },
            {
              "color": "dark-green",
              "value": 60
            }
          ]
        },
        "title": "$${__series.name}",
        "unit": "short"
          },
          "overrides": [],
          "values": true
        },
        "orientation": "auto",
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "6.6.2",
      "targets": [
        {
          "expr": "count(pipeline_job_last_completion) - count(pipeline_job_last_completion offset $__interval )",
          "format": "time_series",
          "instant": true,
          "interval": "",
          "legendFormat": "Jobs",
          "refId": "B"
        },
        {
          "expr": "count(pipeline_task_last_completion) - count(pipeline_task_last_completion offset $__interval )",
          "format": "time_series",
          "instant": true,
          "legendFormat": "Tasks",
          "refId": "A"
        }
      ],
      "timeFrom": "24h",
      "timeShift": null,
      "title": "Completions",
      "transparent": true,
      "type": "gauge"
    },
    {
      "datasource": null,
      "description": "",
      "gridPos": {
        "h": 6,
        "w": 8,
        "x": 15,
        "y": 0
      },
      "hideTimeOverride": false,
      "id": 16,
      "interval": "24h",
      "links": [],
      "options": {
        "fieldOptions": {
          "calcs": [
        "lastNotNull"
          ],
          "defaults": {
        "mappings": [
          {
            "from": "",
            "id": 3,
            "operator": "",
            "text": "0",
            "to": "",
            "type": 1,
            "value": "null"
          }
        ],
        "max": 60,
        "min": 0,
        "thresholds": {
          "mode": "absolute",
          "steps": [
            {
              "color": "dark-green",
              "value": null
            },
            {
              "color": "dark-green",
              "value": 0
            },
            {
              "color": "semi-dark-yellow",
              "value": 10
            },
            {
              "color": "dark-orange",
              "value": 20
            },
            {
              "color": "dark-red",
              "value": 40
            }
          ]
        },
        "title": "",
        "unit": "none"
          },
          "overrides": [],
          "values": true
        },
        "orientation": "auto",
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "6.6.2",
      "targets": [
        {
          "expr": "(count(pipeline_job_last_failure) - (count(pipeline_job_last_failure offset $__interval == 0) or (1-absent(pipeline_job_last_failure==NA)))) or 1- absent(pipeline_job_last_failure == NA)",
          "format": "time_series",
          "instant": true,
          "legendFormat": "Jobs",
          "refId": "B"
        },
        {
          "expr": "(count(pipeline_task_last_failure) - (count(pipeline_task_last_failure offset $__interval == 0) or (1-absent(pipeline_task_last_failure==NA)))) or 1- absent(pipeline_task_last_failure == NA)",
          "instant": true,
          "legendFormat": "Tasks",
          "refId": "A"
        }
      ],
      "timeFrom": "24h",
      "timeShift": null,
      "title": "Failures",
      "transparent": true,
      "type": "gauge"
    },
    {
      "aliasColors": {},
      "bars": false,
      "cacheTimeout": null,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fill": 1,
      "fillGradient": 4,
      "gridPos": {
        "h": 5,
        "w": 24,
        "x": 0,
        "y": 6
      },
      "hiddenSeries": false,
      "hideTimeOverride": false,
      "id": 12,
      "interval": "",
      "legend": {
        "alignAsTable": true,
        "avg": false,
        "current": true,
        "hideEmpty": false,
        "hideZero": true,
        "max": false,
        "min": false,
        "rightSide": true,
        "show": true,
        "total": false,
        "values": true
      },
      "lines": true,
      "linewidth": 1,
      "links": [],
      "nullPointMode": "connected",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pluginVersion": "6.6.2",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": true,
      "targets": [
        {
          "expr": "sum (rate (pipeline_job_duration_seconds[10m])) by (jobId) * 600",
          "format": "time_series",
          "instant": false,
          "interval": "10s",
          "intervalFactor": 1,
          "legendFormat": "{{jobId}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": "2h",
      "timeRegions": [],
      "timeShift": null,
      "title": "Job Outlook",
      "tooltip": {
        "shared": true,
        "sort": 2,
        "value_type": "individual"
      },
      "transparent": true,
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "s",
          "label": "",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": false
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fill": 1,
      "fillGradient": 6,
      "gridPos": {
        "h": 5,
        "w": 24,
        "x": 0,
        "y": 11
      },
      "hiddenSeries": false,
      "id": 14,
      "legend": {
        "alignAsTable": true,
        "avg": false,
        "current": true,
        "hideEmpty": true,
        "hideZero": true,
        "max": false,
        "min": false,
        "rightSide": true,
        "show": true,
        "total": false,
        "values": true
      },
      "lines": true,
      "linewidth": 2,
      "nullPointMode": "connected",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": true,
      "targets": [
        {
          "expr": "sum (rate (pipeline_task_duration_seconds[2m])) by (taskId) * 120",
          "interval": "10s",
          "legendFormat": "{{taskId}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": "2h",
      "timeRegions": [],
      "timeShift": null,
      "title": "Task Outlook",
      "tooltip": {
        "shared": false,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "s",
          "label": "",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": false
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": true,
      "cacheTimeout": null,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 16
      },
      "hiddenSeries": false,
      "hideTimeOverride": false,
      "id": 4,
      "interval": "",
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": false,
      "linewidth": 1,
      "links": [],
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pluginVersion": "6.6.2",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "topk(10,count({__name__=\"pipeline_job_last_completion\"}) by (jobId))",
          "format": "time_series",
          "instant": true,
          "interval": "",
          "legendFormat": "{{jobId}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": "24h",
      "timeRegions": [],
      "timeShift": null,
      "title": "Top 10 job Executions",
      "tooltip": {
        "shared": false,
        "sort": 2,
        "value_type": "individual"
      },
      "transparent": true,
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "series",
        "name": null,
        "show": true,
        "values": [
          "current"
        ]
      },
      "yaxes": [
        {
          "format": "short",
          "label": "Count",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": false
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": true,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 16
      },
      "hiddenSeries": false,
      "id": 6,
      "legend": {
        "alignAsTable": false,
        "avg": false,
        "current": false,
        "hideEmpty": true,
        "hideZero": true,
        "max": false,
        "min": false,
        "rightSide": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": false,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "topk(10,count({__name__=\"pipeline_task_last_completion\"}) by (taskId))",
          "format": "time_series",
          "instant": true,
          "legendFormat": "{{taskId}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": "24h",
      "timeRegions": [],
      "timeShift": null,
      "title": "Top 10 task executions",
      "tooltip": {
        "shared": false,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "series",
        "name": null,
        "show": true,
        "values": [
          "total"
        ]
      },
      "yaxes": [
        {
          "decimals": null,
          "format": "none",
          "label": "Count",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": false
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": true,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 24
      },
      "hiddenSeries": false,
      "id": 10,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": false,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "topk(10,avg(pipeline_task_duration_seconds) by (taskId))",
          "format": "time_series",
          "instant": true,
          "legendFormat": "{{taskId}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": "24h",
      "timeRegions": [],
      "timeShift": null,
      "title": "Long Running Tasks(10)",
      "tooltip": {
        "shared": false,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "series",
        "name": null,
        "show": true,
        "values": [
          "current"
        ]
      },
      "yaxes": [
        {
          "format": "s",
          "label": "",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": false
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": true,
      "dashLength": 10,
      "dashes": false,
      "datasource": null,
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 24
      },
      "hiddenSeries": false,
      "hideTimeOverride": false,
      "id": 8,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": false,
        "total": false,
        "values": false
      },
      "lines": false,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "topk(10,avg(pipeline_job_duration_seconds) by (jobId))",
          "format": "time_series",
          "instant": true,
          "legendFormat": "{{jobId}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": "24h",
      "timeRegions": [],
      "timeShift": null,
      "title": "Long Running Jobs(10)",
      "tooltip": {
        "shared": false,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "series",
        "name": null,
        "show": true,
        "values": [
          "total"
        ]
      },
      "yaxes": [
        {
          "format": "s",
          "label": "",
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": false
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
      ],
      "refresh": "5s",
      "schemaVersion": 22,
      "style": "dark",
      "tags": [],
      "templating": {
    "list": []
      },
      "time": {
    "from": "now-5m",
    "to": "now"
      },
      "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
      },
      "timezone": "",
      "title": "PipelineMetrics",
      "uid": "S8HrL1lZz",
      "version": 13
    }

PIPELINEDASHBOARD

  grafanaconfig = <<GFNCONFIG
#!/bin/bash
kubectl create namespace ${var.grafana-ns}
kubectl apply -n ${var.grafana-ns} -f output/grafana-efs.yaml
kubectl apply -n ${var.grafana-ns} -f output/pipeline-dashboard.yaml
helm del -n  ${var.grafana-ns} grafana  2>/dev/null
helm install grafana grafana/grafana --namespace ${var.grafana-ns} -f output/grfanaopts.yaml
GFNCONFIG
}


resource "local_file" "gfnfs" {
  content     = local.efsconfiggfn
  filename = "output/grafana-efs.yaml"
  file_permission = 0755
}

resource "local_file" "pipelinedb" {
  content     = local.pipelinedashboard
  filename = "output/pipeline-dashboard.yaml"
  file_permission = 0755
}
resource "local_file" "installgfn" {
  content = local.grafanaconfig
  filename = "output/install_gfn.sh"
  file_permission = 0755
}

resource "local_file" "grafanaopts" {
  content = local.grafanahelmopts
  filename = "output/grfanaopts.yaml"
  file_permission = 0755
}



