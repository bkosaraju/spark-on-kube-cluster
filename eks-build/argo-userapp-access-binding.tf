locals {
uirolesmapping =<<APPTOUIMAPPING
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-${var.application-namespace}-ui-access-binding-admin
  namespace: ${var.application-namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name:  ${var.cluster-name}-${var.application-namespace}-admin
subjects:
  - kind: ServiceAccount
    name: argo-ui-admin-account
    namespace: ${var.argo-ns}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-${var.application-namespace}-ui-access-binding-edit
  namespace: ${var.application-namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name:  ${var.cluster-name}-${var.application-namespace}-edit
subjects:
  - kind: ServiceAccount
    name: argo-ui-edit-account
    namespace: ${var.argo-ns}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-${var.application-namespace}-ui-access-binding-view
  namespace: ${var.application-namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name:  ${var.cluster-name}-${var.application-namespace}-view
subjects:
  - kind: ServiceAccount
    name: argo-ui-view-account
    namespace: ${var.argo-ns}

APPTOUIMAPPING

}

resource "local_file" "appuirolemapping" {
    content     = local.uirolesmapping
    filename = "output/app-to-ui-role-mapping.yaml"
}

