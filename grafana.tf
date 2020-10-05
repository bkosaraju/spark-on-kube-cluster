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

  grafanaconfig = <<GFNCONFIG
#!/bin/bash
kubectl create namespace ${var.grafana-ns}
kubectl -n kube-system delete deployment tiller-deploy 2>/dev/null
kubectl -n kube-system delete service/tiller-deploy 2>/dev/null
kubectl apply -n ${var.grafana-ns} -f output/grafana-efs.yaml
kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade --wait
helm del --purge grafana 2>/dev/null
  helm install stable/grafana \
    --name grafana \
    --namespace ${var.grafana-ns} \
    --set adminPassword=${var.grafana-admin-temp-password} \
    --set datasources."datasources\.yaml".apiVersion=1 \
    --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
    --set datasources."datasources\.yaml".datasources[0].type=prometheus \
    --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.${var.prometheus-ns}.svc.cluster.local \
    --set datasources."datasources\.yaml".datasources[0].access=proxy \
    --set datasources."datasources\.yaml".datasources[0].isDefault=true \
    --set service.type=LoadBalancer \
    --set persistence.enabled=true \
    --set persistence.storageClassName="${var.grafana-ns}-efs-sc" \
    --set persistence.size=100Gi \
    --set persistence.existingClaim="${var.grafana-ns}-efs-claim" \
    --set persistence.accessModes="[ReadWriteMany]" \
    --set persistence.subPath="data/${var.grafana-ns}" \
    --set resources.requests.cpu="2000m" \
    --set resources.requests.memory="8Gi" \
    --set resources.limits.cpu="2000m" \
    --set resources.limits.memory="8Gi"
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



