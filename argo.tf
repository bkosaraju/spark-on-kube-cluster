locals {

argos3artifact =<<ARGOS3CONFIG
data:
  config: |
    artifactRepository:
      s3:
        bucket: ${var.argo-s3-bucket}
        endpoint: s3.amazonaws.com
ARGOS3CONFIG

argoconfig = <<ARGCONFIG
#!/bin/bash
kubectl create namespace ${var.argo-ns}
kubectl  -n ${var.argo-ns} apply -f https://raw.githubusercontent.com/argoproj/argo/${var.argo-version}/manifests/install.yaml
kubectl -n argo patch configmap/workflow-controller-configmap --patch "$(cat output/argos3artifactconfig.yaml)"
kubectl -n argo patch svc argo-server -p '{"spec": {"type": "LoadBalancer"}}'

ARGCONFIG

}

resource "local_file" "argos3artifact" {
  content = local.argos3artifact
  filename = "output/argos3artifactconfig.yaml"
  file_permission = 0755
}
resource "local_file" "installargo" {
  content = local.argoconfig
  filename = "output/install_argo.sh"
  file_permission = 0755
}

