#!/bin/bash
helm del --purge grafana 2>/dev/null
helm del --purge prometheus 2>/dev/null
kubectl -n argo patch svc argo-server -p '{"spec": {"type": "NodePort"}}' 2>/dev/null
kubectl -n prometheus patch svc prometheus-pushgateway -p '{"spec": {"type": "NodePort"}}' 2>/dev/null
terraform destroy --force
