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

  grafanaconfig = <<GFNCONFIG
#!/bin/bash
kubectl create namespace ${var.grafana-ns}
kubectl apply -n ${var.grafana-ns} -f output/grafana-efs.yaml
helm del -n  ${var.grafana-ns} grafana  2>/dev/null
helm install grafana grafana/grafana --namespace ${var.grafana-ns} -f output/grfanaopts.yaml
GFNCONFIG
}


resource "local_file" "gfnfs" {
  content     = local.efsconfiggfn
  filename = "output/grafana-efs.yaml"
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



