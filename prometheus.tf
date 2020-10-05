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
    command: [ '/bin/sh', '-c','ls -ls /data;mkdir -p /efs/data/${var.prometheus-ns}/server  /efs/data/${var.prometheus-ns}/alertmanager  /efs/data/${var.prometheus-ns}/pushgateway; chown -R 65534:65534 /efs/data/${var.prometheus-ns}']
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


  prometheusconfig = <<PMCONFIG
#!/bin/bash

#Deploy metrics service
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

kubectl create namespace ${var.prometheus-ns} 2>/dev/null
kubectl apply -f output/initvolume.yaml
kubectl -n kube-system delete deployment tiller-deploy 2>/dev/null
kubectl -n kube-system delete service/tiller-deploy 2>/dev/null
kubectl apply -n ${var.prometheus-ns} -f output/prometheus-efs.yaml
kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade --wait
helm del --purge prometheus 2>/dev/null
kubectl delete -f output/initvolume.yaml
helm install stable/prometheus \
    --name prometheus \
    --namespace ${var.prometheus-ns} \
    --set server.persistentVolume.enabled="true" \
    --set server.persistentVolume.existingClaim="${var.prometheus-ns}-efs-claim" \
    --set server.persistentVolume.mountPath="/data/${var.prometheus-ns}/server" \
    --set server.persistentVolume.subPath="data/${var.prometheus-ns}/server" \
    --set server.persistentVolume.size="100Gi" \
    --set server.persistentVolume.storageClass="${var.prometheus-ns}-efs-sc" \
    --set alertmanager.persistentVolume.enabled="true" \
    --set alertmanager.persistentVolume.existingClaim="${var.prometheus-ns}-efs-claim" \
    --set alertmanager.persistentVolume.mountPath="/data/${var.prometheus-ns}/alertmanager" \
    --set alertmanager.persistentVolume.subPath="data/${var.prometheus-ns}/alertmanager" \
    --set alertmanager.persistentVolume.size="100Gi" \
    --set alertmanager.persistentVolume.storageClass="${var.prometheus-ns}-efs-sc" \
    --set pushgateway.persistentVolume.enabled="true" \
    --set pushgateway.persistentVolume.existingClaim="${var.prometheus-ns}-efs-claim" \
    --set pushgateway.persistentVolume.mountPath="/data/${var.prometheus-ns}/pushgateway" \
    --set pushgateway.persistentVolume.subPath="data/${var.prometheus-ns}/pushgateway" \
    --set pushgateway.persistentVolume.size="100Gi" \
    --set pushgateway.persistentVolume.storageClass="${var.prometheus-ns}-efs-sc" \
    --set server.retention="30d" \
    --set server.resources.requests.cpu="1500m" \
    --set server.resources.requests.memory="8Gi" \
    --set server.resources.limits.cpu="1500m" \
    --set server.resources.limits.memory="8Gi" \
    --set alertmanager.resources.requests.cpu="1000m" \
    --set alertmanager.resources.requests.memory="4Gi" \
    --set alertmanager.resources.limits.cpu="1000m" \
    --set alertmanager.resources.limits.memory="4Gi" \
    --set pushgateway.resources.requests.cpu="1000m" \
    --set pushgateway.resources.requests.memory="4Gi" \
    --set pushgateway.resources.limits.cpu="1000m" \
    --set pushgateway.resources.limits.memory="4Gi"
kubectl -n ${var.prometheus-ns} patch svc prometheus-pushgateway -p '{"spec": {"type": "LoadBalancer"}}'
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



