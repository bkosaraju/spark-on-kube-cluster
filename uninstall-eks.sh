#!/bin/bash
cp output/kubeconfig output/kubeconfig.bkp 2>/dev/null
helm del --purge -n grafana grafana 2>/dev/null
helm del --purge -n prometheus  prometheus-community/prometheus 2>/dev/null
kubectl delete -f output/nginx-controller.yaml
cd post-build
terraform destroy --force
terraform destroy --force
cd ../
terraform destroy --force
terraform destroy --force
