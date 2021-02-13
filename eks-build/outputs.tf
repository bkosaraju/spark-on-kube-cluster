resource "random_string" "random" {
  length = 16
  special = true
  override_special = "@#%&*()-_=+[]{}<>:?"
  min_numeric = 1
  min_special = 1
  min_upper = 1
}
locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.cluster-worker-role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${aws_iam_role.ns-admin.arn}
      username: ${var.cluster-name}-${var.application-namespace}-admin
      groups:
       - ${var.cluster-name}-${var.application-namespace}-admin
    - rolearn: ${aws_iam_role.ns-edit.arn}
      username: ${var.cluster-name}-${var.application-namespace}-edit
      groups:
       - ${var.cluster-name}-${var.application-namespace}-edit
    - rolearn: ${aws_iam_role.ns-view.arn}
      username: ${var.cluster-name}-${var.application-namespace}-view
      groups:
       - ${var.cluster-name}-${var.application-namespace}-view

CONFIGMAPAWSAUTH

  kubeconfig = <<KUBECONFIG

apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
#    namespace: ${var.application-namespace}
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${var.cluster-name}"
#        - "--role"
#        - "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster-name}-${var.application-namespace}-admin-role"
#        - "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster-name}-${var.application-namespace}-edit-role"
#        - "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster-name}-${var.application-namespace}-view-role"
KUBECONFIG

  efsconfig = <<EFSCONFIG

kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ${var.application-namespace}-efs-sc
provisioner: efs.csi.aws.com
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${var.application-namespace}-efs-claim
  namespace : ${var.application-namespace}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${var.application-namespace}-efs-sc
  resources:
    requests:
      storage: 500Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${var.application-namespace}-efs-pv
spec:
  capacity:
    storage: 500Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${var.application-namespace}-efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${aws_efs_file_system.cluster-efs.id}"
EFSCONFIG


  sparkuser = <<SPARKUSER


apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark
  namespace: "${var.application-namespace}"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spark-role
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
  - kind: ServiceAccount
    name: spark
    namespace: "${var.application-namespace}"

SPARKUSER

  autoscale = <<AUTOSCALE

---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
  name: cluster-autoscaler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
  - apiGroups: [""]
    resources: ["events", "endpoints"]
    verbs: ["create", "patch"]
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]
  - apiGroups: [""]
    resources: ["pods/status"]
    verbs: ["update"]
  - apiGroups: [""]
    resources: ["endpoints"]
    resourceNames: ["cluster-autoscaler"]
    verbs: ["get", "update"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["watch", "list", "get", "update"]
  - apiGroups: [""]
    resources:
      - "pods"
      - "services"
      - "replicationcontrollers"
      - "persistentvolumeclaims"
      - "persistentvolumes"
    verbs: ["watch", "list", "get"]
  - apiGroups: ["extensions"]
    resources: ["replicasets", "daemonsets"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["watch", "list"]
  - apiGroups: ["apps"]
    resources: ["statefulsets", "replicasets", "daemonsets"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses", "csinodes"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["batch", "extensions"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create","list","watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
    verbs: ["delete", "get", "update", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-autoscaler
subjects:
  - kind: ServiceAccount
    name: cluster-autoscaler
    namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cluster-autoscaler
subjects:
  - kind: ServiceAccount
    name: cluster-autoscaler
    namespace: kube-system

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '8085'
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
        - image: k8s.gcr.io/cluster-autoscaler:v1.14.6
          name: cluster-autoscaler
          resources:
            limits:
              cpu: 100m
              memory: 300Mi
            requests:
              cpu: 100m
              memory: 300Mi
          command:
            - ./cluster-autoscaler
            - --v=4
            - --stderrthreshold=info
            - --cloud-provider=aws
            - --skip-nodes-with-local-storage=false
            - --expander=least-waste
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${var.cluster-name}
            - --balance-similar-node-groups
            - --skip-nodes-with-system-pods=false
          volumeMounts:
            - name: ssl-certs
              mountPath: /etc/ssl/certs/ca-certificates.crt
              readOnly: true
          env:
            - name: AWS_REGION
              value: ${data.aws_region.current.name} 
          imagePullPolicy: "Always"
      volumes:
        - name: ssl-certs
          hostPath:
            path: "/etc/ssl/certs/ca-bundle.crt"

AUTOSCALE



  initcluster = <<INITSCRIPT

#!/bin/bash
export KUBECONFIG=$PWD/output/kubeconfig
cp $PWD/output/kubeconfig ~/.kube/config
echo "Creating primary namespace.."
kubectl create namespace ${var.application-namespace} || true
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
kubectl -n ${var.prometheus-ns} delete -f output/initvolume.yaml
#Create OAuth Test Users
aws cognito-idp admin-delete-user --user-pool-id ${aws_cognito_user_pool.pool.id} --username app_admin 2>/dev/null
aws cognito-idp admin-delete-user --user-pool-id ${aws_cognito_user_pool.pool.id} --username app_edit 2>/dev/null
aws cognito-idp admin-delete-user --user-pool-id ${aws_cognito_user_pool.pool.id} --username app_readonly 2>/dev/null
aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.pool.id} --username app_admin --user-attributes '[{"Name": "email","Value": "app_admin@${var.eks-hosted-dnszone}"}]' --message-action SUPPRESS --temporary-password "${random_string.random.result}"
aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.pool.id} --username app_readonly --user-attributes '[{"Name": "email","Value": "app_readonly@${var.eks-hosted-dnszone}"}]' --message-action SUPPRESS --temporary-password "${random_string.random.result}"
aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.pool.id} --username app_edit --user-attributes '[{"Name": "email","Value": "app_edit@${var.eks-hosted-dnszone}"}]' --message-action SUPPRESS --temporary-password "${random_string.random.result}"
INITSCRIPT

  clusterroles = <<ROLES
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: "${var.application-namespace}"
  name: ${var.cluster-name}-${var.application-namespace}-admin
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch", "extensions"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: "${var.application-namespace}"
  name: ${var.cluster-name}-${var.application-namespace}-edit
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: "${var.application-namespace}"
  name: ${var.cluster-name}-${var.application-namespace}-view
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: "${var.application-namespace}"
  name: ${var.cluster-name}-${var.application-namespace}-admin
subjects:
- kind: Group
  name: ${var.cluster-name}-${var.application-namespace}-admin
roleRef:
  kind: Role
  name: ${var.cluster-name}-${var.application-namespace}-admin
  apiGroup: rbac.authorization.k8s.io

---

kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: "${var.application-namespace}"
  name: ${var.cluster-name}-${var.application-namespace}-edit
subjects:
- kind: Group
  name: ${var.cluster-name}-${var.application-namespace}-edit
roleRef:
  kind: Role
  name: ${var.cluster-name}-${var.application-namespace}-edit
  apiGroup: rbac.authorization.k8s.io
---

kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: "${var.application-namespace}"
  name: ${var.cluster-name}-${var.application-namespace}-view
subjects:
- kind: Group
  name: ${var.cluster-name}-${var.application-namespace}-view
roleRef:
  kind: Role
  name: ${var.cluster-name}-${var.application-namespace}-view
  apiGroup: rbac.authorization.k8s.io

ROLES

}




resource "local_file" "efsmount" {
    content     = local.efsconfig
    file_permission = 0755
    filename = "output/efsconfig.yaml"
}

resource "local_file" "kubeconfig" {
    content     = local.kubeconfig
    filename = "output/kubeconfig"
    file_permission = "0700"
}

resource "local_file" "homedirkubeconfig" {
  content     = local.kubeconfig
  filename = pathexpand("~/.kube/config")
  file_permission = "0700"
}

resource "local_file" "aws_auth" {
    content     = local.config_map_aws_auth
    filename = "output/config_map_aws_auth.yaml"
}

resource "local_file" "sparkuser" {
    content     = local.sparkuser
    filename = "output/sparkuser.yaml"
}


resource "local_file" "initscript" {
    content     = local.initcluster
    filename = "post_install.sh"
    file_permission = 0755
}

resource "local_file" "clusterroles" {
    content     = local.clusterroles
    filename = "output/cluster_roles.yaml"
}
resource "local_file" "autoscalar" {
    content     = local.autoscale
    filename = "output/cluster-autoscaler-autodiscover.yaml"
}



