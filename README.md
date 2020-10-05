# spark-on-kube-cluster

Repository for provision Kubernetes(EKS) with following components.

1. EKS Cluster
2. OpenID integration for provision IAM based authentication and Authorization to EKS cluster
3. EFS for shared storage(persistence volume for containers) - RBAC Acces to users 
4. Bastion host for user operations (one entry point to environment)
5. Nat Gateway (govern external routes)
6. Worker nodes (used as Spark Executors)
7. Autoscaling groups (dynamically scale up and down based of spark execution)
8. configure Application namespace (dataengineering)
9. Prometheous and pushgateway to monitor and accept app metrics(efs as storage to get multi AZ).
10. Grafana for dashborads and integrate with prometheous(efs as storage to get multi AZ).
11. Install Argo Scheduler and configure S3 for app cache.

Where can I get the latest release?
-----------------------------------
You can download source from [SCM](https://github.com/bkosaraju/spark-on-kube-cluster).

## Install Instructions 

```bash
terraform init
./instal_eks.sh 
```

## Un install Instructions


```bash
terraform init
./uninstal_eks.sh 
```

## Contributing
Please feel free to raise a pull request in case if you feel like something can be updated or contributed

## License
[Apache](http://www.apache.org/licenses/LICENSE-2.0.txt)
