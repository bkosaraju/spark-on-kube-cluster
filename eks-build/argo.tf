locals {

argos3artifact =<<ARGOS3CONFIG
data:
  config: |
    artifactRepository:
      s3:
        bucket: ${var.argo-s3-bucket}
        endpoint: s3.amazonaws.com
        roleArn: ${aws_iam_role.argo-artifact-arp.arn}
    sso:
        issuer: https://cognito-idp.ap-southeast-2.amazonaws.com/${aws_cognito_user_pool.pool.id}
        clientId:
          name: client-id-secret
          key: client-id-key
        clientSecret:
          name: client-secret-secret
          key: client-secret-key
        redirectUrl: https://argo.${var.cluster-name}.${var.eks-hosted-dnszone}/oauth2/callback
        scopes:
         - openid
        rbac:
          enabled: true

ARGOS3CONFIG

argoingress =<<ARGOINGRESS
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argo-server-ingress
  annotations:
    ingress.kubernetes.io/proxy-body-size: 100M
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/app-root: "/"
spec:
  rules:
  - host: argo.${var.cluster-name}.${var.eks-hosted-dnszone}
    http:
      paths:
      - path: /
        backend:
          serviceName: argo-server
          servicePort: 2746
ARGOINGRESS

argosso =<<ARGOSSO
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argo-server
spec:
  selector:
    matchLabels:
      app: argo-server
  template:
    metadata:
      labels:
        app: argo-server
    spec:
      containers:
      - args:
        - server
        - --auth-mode
        - sso
        image: argoproj/argocli:latest
        name: argo-server
        ports:
        - containerPort: 2746
          name: web
        readinessProbe:
          httpGet:
            path: /
            port: 2746
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 20
        volumeMounts:
        - mountPath: /tmp
          name: tmp
      nodeSelector:
        kubernetes.io/os: linux
      securityContext:
        runAsNonRoot: true
      serviceAccountName: argo-server
      volumes:
      - emptyDir: {}
        name: tmp

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workflow-controller
spec:
  selector:
    matchLabels:
      app: workflow-controller
  template:
    metadata:
      labels:
        app: workflow-controller
    spec:
      containers:
      - args:
        - --configmap
        - workflow-controller-configmap
        - --executor-image
        - argoproj/argoexec:latest
        command:
        - workflow-controller
        image: argoproj/workflow-controller:${var.argo-wf-controller-version}
        name: workflow-controller
        env:
        - name: LEADER_ELECTION_IDENTITY
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
      nodeSelector:
        kubernetes.io/os: linux
      securityContext:
        runAsNonRoot: true
      serviceAccountName: argo
ARGOSSO

argousermap = <<ARGOUSERMAP
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-ui-view-account
  annotations:
    workflows.argoproj.io/rbac-rule: "true"
    workflows.argoproj.io/rbac-rule-precedence: "0"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-aggregate-to-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-aggregate-to-viwe
subjects:
  - kind: ServiceAccount
    name: argo-ui-view-account
    namespace: ${var.argo-ns}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-events-aggregate-to-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-events-aggregate-to-viwe
subjects:
  - kind: ServiceAccount
    name: argo-ui-view-account
    namespace: ${var.argo-ns}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-ui-edit-account
  annotations:
    workflows.argoproj.io/rbac-rule:  "email in ['app_edit@${var.eks-hosted-dnszone}']"
    workflows.argoproj.io/rbac-rule-precedence: "1"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-aggregate-to-edit
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-aggregate-to-admin
subjects:
  - kind: ServiceAccount
    name: argo-ui-edit-account
    namespace: ${var.argo-ns}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-events-aggregate-to-edit
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-events-aggregate-to-admin
subjects:
  - kind: ServiceAccount
    name: argo-ui-edit-account
    namespace: ${var.argo-ns}
---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-ui-admin-account
  annotations:
    workflows.argoproj.io/rbac-rule: "email in ['app_admin@${var.eks-hosted-dnszone}']"
    workflows.argoproj.io/rbac-rule-precedence: "2"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-aggregate-to-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-aggregate-to-admin
subjects:
  - kind: ServiceAccount
    name: argo-ui-admin-account
    namespace: ${var.argo-ns}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-events-aggregate-to-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-events-aggregate-to-admin
subjects:
  - kind: ServiceAccount
    name: argo-ui-admin-account
    namespace: ${var.argo-ns}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-role
rules:
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - create
  - get
  - update
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get

---

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-role
rules:
# pod get/watch is used to identify the container IDs of the current pod
# pod patch is used to annotate the step's outputs back to controller (e.g. artifact location)
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - watch
  - patch
# logs get/watch are used to get the pods logs for script outputs, and for log archival
- apiGroups:
  - ""
  resources:
  - pods/log
  verbs:
  - get
  - watch


---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-role
subjects:
- kind: ServiceAccount
  name: argo
  namespace: ${var.argo-ns}
ARGOUSERMAP

argoserverrolefix = <<ARGOSERVERROLEFIX
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-server-cluster-role
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - get
      - watch
      - list
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - get
      - create
  - apiGroups:
      - ""
    resources:
      - pods
      - pods/exec
      - pods/log
    verbs:
      - get
      - list
      - watch
      - delete
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - watch
      - create
      - patch
  - apiGroups:
      - ""
    resources:
      - serviceaccounts
    verbs:
      - get
      - list
  - apiGroups:
      - argoproj.io
    resources:
      - workflows
      - workfloweventbindings
      - workflowtemplates
      - cronworkflows
      - clusterworkflowtemplates
    verbs:
      - create
      - get
      - list
      - watch
      - update
      - patch
      - delete

ARGOSERVERROLEFIX

argoevtbinding =<<ARGOEVTBINDING
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-events-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-events-role
subjects:
  - kind: ServiceAccount
    name: argo-events-sa
    namespace: ${var.argo-ns}-events
  - kind: ServiceAccount
    name: argo-server
    namespace: ${var.argo-ns}
ARGOEVTBINDING

argoconfig =<<ARGCONFIG
#!/bin/bash
kubectl create namespace ${var.argo-ns}
kubectl delete secret -n ${var.argo-ns} client-id-secret 2>/dev/null
kubectl delete secret -n ${var.argo-ns} client-secret-secret 2>/dev/null
kubectl create secret -n ${var.argo-ns} generic client-id-secret --from-literal=client-id-key=${aws_cognito_user_pool_client.argo-pool-client.id}
kubectl create secret -n ${var.argo-ns} generic client-secret-secret --from-literal=client-secret-key=${aws_cognito_user_pool_client.argo-pool-client.client_secret}
kubectl -n ${var.argo-ns} apply -f https://raw.githubusercontent.com/argoproj/argo/latest/manifests/install.yaml
kubectl -n ${var.argo-ns} patch configmap/workflow-controller-configmap --patch "$(cat output/argo-config-map.yaml)"
kubectl apply -f output/argo-access-fix.yaml
kubectl -n  ${var.argo-ns} apply -f output/argo-ingress.yaml
kubectl -n  ${var.argo-ns} delete -f  output/argo-enable-sso.yaml
kubectl -n  ${var.argo-ns} apply -f output/argo-enable-sso.yaml
kubectl -n  ${var.argo-ns} apply -f output/argo-ui-user-map.yaml
kubectl -n  ${var.argo-ns} delete "$(kubectl get pods -l app=argo-server -n  ${var.argo-ns} -o name)" 2>/dev/null
kubectl -n  ${var.argo-ns} delete "$(kubectl get pods -l app=workflow-controller -n  ${var.argo-ns} -o name)" 2>/dev/null

#Argo Events

kubectl create namespace ${var.argo-ns}-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
#kubectl -n ${var.argo-ns}-events apply -f https://raw.githubusercontent.com/argoproj/argo-events/latest/manifests/namespace-install.yaml
#kubectl -n ${var.argo-ns}-events apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
#kubectl -n ${var.argo-ns}-events apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/event-sources/webhook.yaml
#kubectl apply -n ${var.argo-ns}-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/sensors/webhook.yaml
kubectl apply -f output/argo-event-access.yaml
kubectl apply -f output/app-to-ui-role-mapping.yaml
ARGCONFIG
}

resource "local_file" "argos3artifact" {
  content = local.argos3artifact
  filename = "output/argo-config-map.yaml"
  file_permission = 0755
}

resource "local_file" "installargo" {
  content = local.argoconfig
  filename = "output/install_argo.sh"
  file_permission = 0755
}

resource "local_file" "installingress" {
  content = local.argoingress
  filename = "output/argo-ingress.yaml"
  file_permission = 0755
}

resource "local_file" "serveraccessfix" {
  content = local.argoserverrolefix
  filename = "output/argo-access-fix.yaml"
  file_permission = 0755
}

resource "local_file" "eventaccess" {
  content = local.argoevtbinding
  filename = "output/argo-event-access.yaml"
  file_permission = 0755
}
resource "local_file" "argosso" {
  content = local.argosso
  filename = "output/argo-enable-sso.yaml"
  file_permission = 0755
}
resource "local_file" "argousermap" {
  content = local.argousermap
  filename = "output/argo-ui-user-map.yaml"
  file_permission = 0755
}

