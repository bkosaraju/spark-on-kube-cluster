locals {
  efsconfigpm = <<PMSEFSCONFIG
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ${var.prometheus-ns}-efs-sc
provisioner: efs.csi.aws.com
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${var.prometheus-ns}-efs-claim
  namespace : ${var.prometheus-ns}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${var.prometheus-ns}-efs-sc
  resources:
    requests:
      storage: 500Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${var.prometheus-ns}-efs-pv
spec:
  capacity:
    storage: 500Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${var.prometheus-ns}-efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${aws_efs_file_system.cluster-efs.id}"
PMSEFSCONFIG

  permissionhack = <<BUSYBOX
apiVersion: v1
kind: Pod
metadata:
  name: inintprometheus
  namespace: ${var.prometheus-ns}
  labels:
    app: inintprometheus
spec:
  containers:
  - image: busybox
    command: [ '/bin/sh', '-c', '-x', 'find /efs ;mkdir -p /efs/data/${var.prometheus-ns}/server  /efs/data/${var.prometheus-ns}/alertmanager  /efs/data/${var.prometheus-ns}/pushgateway; chown -R 65534:65534 /efs/data/${var.prometheus-ns}']
    imagePullPolicy: IfNotPresent
    name: busybox
    volumeMounts:
      - name: persistent-storage
        mountPath: /efs
  restartPolicy: Never
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: ${var.prometheus-ns}-efs-claim
BUSYBOX


pmhelmcnfg = <<PMHELMCNFG
server:
  retention: 30d
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  persistentVolume:
    enabled: true
    existingClaim: ${var.prometheus-ns}-efs-claim
    mountPath: /data/${var.prometheus-ns}/server
    subPath: data/${var.prometheus-ns}/server
    size: 100Gi
    storageClass: ${var.prometheus-ns}-efs-sc
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
       - "prometheus.${var.cluster-name}.${var.eks-hosted-dnszone}"
    extraPaths:
      - path: /*
        backend:
          serviceName: prometheus-server
          servicePort: 80
  prometheusSpec:
    externalUrl: http://prometheus.${var.cluster-name}.${var.eks-hosted-dnszone}
alertmanager:
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  persistentVolume:
    enabled: true
    existingClaim: ${var.prometheus-ns}-efs-claim
    mountPath: /data/${var.prometheus-ns}/alertmanager
    subPath: data/${var.prometheus-ns}/alertmanager
    size: 100Gi
    storageClass: ${var.prometheus-ns}-efs-sc
pushgateway:
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  persistentVolume:
    enabled: true
    existingClaim: ${var.prometheus-ns}-efs-claim
    mountPath: /data/${var.prometheus-ns}/pushgateway
    subPath: data/${var.prometheus-ns}/pushgateway
    size: 100Gi
    storageClass: ${var.prometheus-ns}-efs-sc
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
      - pushgateway.${var.cluster-name}.${var.eks-hosted-dnszone}
    extraPaths:
      - path: /*
        backend:
          serviceName: prometheus-pushgateway
          servicePort: 9091
PMHELMCNFG

  prometheusconfig = <<PMCONFIG
#!/bin/bash

#Deploy metrics service
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

kubectl create namespace ${var.prometheus-ns} 2>/dev/null
kubectl -n ${var.prometheus-ns} apply -f output/prometheus-efs.yaml
#kubectl -n ${var.prometheus-ns} apply -f output/initvolume.yaml
helm del -n ${var.prometheus-ns}  prometheus  2>/dev/null
helm install prometheus prometheus-community/prometheus --namespace ${var.prometheus-ns} -f output/prometheus-helmcnfg.yaml
#echo "Log from volume initilizer"
#kubectl -n ${var.prometheus-ns} logs -f inintprometheus
#echo "purge volume initilizer"
#kubectl -n ${var.prometheus-ns} delete -f output/initvolume.yaml
PMCONFIG

}

resource "local_file" "pms" {
  content     = local.efsconfigpm
  filename = "output/prometheus-efs.yaml"
  file_permission = 0755
}
resource "local_file" "permissionhack" {
  content = local.permissionhack
  filename = "output/initvolume.yaml"
  file_permission = 0755
}

resource "local_file" "installpm" {
  content = local.prometheusconfig
  filename = "output/install_pm.sh"
  file_permission = 0755
}
resource "local_file" "pmhelmcnfg" {
  content = local.pmhelmcnfg
  filename = "output/prometheus-helmcnfg.yaml"
  file_permission = 0755
}




