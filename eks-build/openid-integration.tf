
data "external" "thumbprint" {
  program = [format("%s/bin/get_thumbprint.sh", path.module), data.aws_region.current.name]
}

resource "aws_iam_openid_connect_provider" "openidprovider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}


data "aws_iam_policy_document" "openid-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.openidprovider.url, "https://", "")}:sub"
      //values   = ["system:serviceaccount:kube-system:aws-node"]
      values   = ["system:serviceaccount:${var.application-namespace}:${var.application-serviceaccount}"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.openidprovider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "arp" {
  assume_role_policy = data.aws_iam_policy_document.openid-assume-role-policy.json
  name               = "${var.cluster-name}-${var.application-namespace}-openid-assumerole-policy"
  tags = map(
  "Name", "${var.application-serviceaccount}-${var.application-namespace}-${var.cluster-name}-openid-assumerole",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}


resource "kubernetes_namespace" "appnamespace" {
  metadata {
    name = var.application-namespace
  }
}

resource "aws_iam_role" "argo-artifact-arp" {
  assume_role_policy = data.aws_iam_policy_document.openid-assume-role-policy.json
  name               = "argo-${var.cluster-name}-openid-assumerole-policy"
  tags = map(
  "Name", "${var.argo-ns}-${var.cluster-name}-openid-assumerole",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}


resource "aws_iam_role_policy_attachment" "eks-argo-s3-iam-policy-attach" {
  role       = aws_iam_role.argo-artifact-arp.name
  policy_arn = aws_iam_policy.argo-s3-config.arn
}
resource "aws_iam_role_policy_attachment" "eks-argo-kms-iam-policy-attach" {
  role       = aws_iam_role.argo-artifact-arp.name
  policy_arn = aws_iam_policy.argo-kms-keyaccess.arn
}




//TODO: Remove and give  access based of needs 


data aws_iam_policy "s3access" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "iamtoserviceaccount" {
  role       = aws_iam_role.arp.name
  policy_arn = data.aws_iam_policy.s3access.arn
}


resource "aws_iam_role_policy_attachment" "kmsaccess" {
  role       = aws_iam_role.arp.name
  policy_arn = aws_iam_policy.application-kms-keyaccess.arn
}

resource "aws_iam_role_policy_attachment" "ekscluster" {
  role       = aws_iam_role.arp.name
  policy_arn = aws_iam_policy.eks-cluster-policy.arn
}


resource "aws_iam_role_policy_attachment" "appconfig" {
  role       = aws_iam_role.arp.name
  policy_arn = aws_iam_policy.application-config.arn
}

resource "aws_iam_role_policy_attachment" "ssmreadonly" {
  role       = aws_iam_role.arp.name
  policy_arn = aws_iam_policy.ssm-read-access.arn
}

resource "aws_iam_role_policy_attachment" "application-admin" {
  role       = aws_iam_role.arp.name
  policy_arn = aws_iam_policy.ns-admin.arn
}

//End of IAM User Access Management

//kube User management 

resource "kubernetes_service_account" "spark" {
  metadata {
    name = var.application-serviceaccount
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.arp.arn
    }
    namespace = var.application-namespace
  }
  automount_service_account_token="true"
}


resource "kubernetes_cluster_role" "spark-role" {
  metadata {
    name = "spark-role"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods","services"]
    verbs      = ["*"]
  }
}


//Give Appropriate local access to user.

resource "kubernetes_cluster_role_binding" "spark-role-binding" {
  metadata {
    name = "spark-role"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }
  subject {
    kind      = "User"
    name      = "admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.application-serviceaccount
    namespace = var.application-namespace
  }
}
