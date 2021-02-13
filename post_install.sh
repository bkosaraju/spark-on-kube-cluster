
#!/bin/bash
export KUBECONFIG=$PWD/output/kubeconfig
cp $PWD/output/kubeconfig ~/.kube/config
echo "Creating primary namespace.."
kubectl create namespace datamarvels || true
echo "Creating primary cluster roles.."
kubectl apply -f output/cluster_roles.yaml
echo "Apply AWS Auth..."
kubectl apply -f output/config_map_aws_auth.yaml
echo "Provision EFS to EKS..."
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
kubectl apply -f output/efsconfig.yaml
echo "Crease spark user.."
#kubectl apply -f output/sparkuser.yaml
echo "Enable Autoscaling.."
kubectl apply -f output/cluster-autoscaler-autodiscover.yaml
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
echo "Install nginx Ingess Service"
kubectl apply -f output/nginx-controller.yaml
#Install helm
echo "Install latest version of helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

#Add required repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

#wait for nginx-controller to be up once done enable ingress for other services
sleep 120
#//TODO: Find a way to identify ingress controller created or not 
#while [ $(kubectl get pods --field-selector=status.phase=Running -n ingress-nginx  | wc -l) -lt 2  ]
#do
#  echo "Waiting for nodes to start and schedule pods.."
#  sleep 5
#done
[[ -f output/install_argo.sh ]] && bash output/install_argo.sh || bash output/install_argo.sh 
[[ -f output/install_pm.sh ]] && bash output/install_pm.sh || bash output/install_pm.sh
[[ -f output/install_gfn.sh ]] && bash output/install_gfn.sh || bash output/install_gfn.sh
#wait for nodes to be up once done enable to LBS and delete volume initializer
kubectl -n prometheus delete -f output/initvolume.yaml
#Create OAuth Test Users
aws cognito-idp admin-delete-user --user-pool-id ap-southeast-2_4apXaVMgW --username app_admin 2>/dev/null
aws cognito-idp admin-delete-user --user-pool-id ap-southeast-2_4apXaVMgW --username app_edit 2>/dev/null
aws cognito-idp admin-delete-user --user-pool-id ap-southeast-2_4apXaVMgW --username app_readonly 2>/dev/null
aws cognito-idp admin-create-user --user-pool-id ap-southeast-2_4apXaVMgW --username app_admin --user-attributes '[{"Name": "email","Value": "app_admin@datamarvels.com"}]' --message-action SUPPRESS --temporary-password "DnWzo1KfT6WN6(]u"
aws cognito-idp admin-create-user --user-pool-id ap-southeast-2_4apXaVMgW --username app_readonly --user-attributes '[{"Name": "email","Value": "app_readonly@datamarvels.com"}]' --message-action SUPPRESS --temporary-password "DnWzo1KfT6WN6(]u"
aws cognito-idp admin-create-user --user-pool-id ap-southeast-2_4apXaVMgW --username app_edit --user-attributes '[{"Name": "email","Value": "app_edit@datamarvels.com"}]' --message-action SUPPRESS --temporary-password "DnWzo1KfT6WN6(]u"
