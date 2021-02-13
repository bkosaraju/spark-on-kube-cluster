#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_iam_role" "cluster-role" {
  name = "${var.cluster-name}-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster-role.name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster-role.name
}

resource "aws_security_group" "cluster-sg" {
  name        = "${var.cluster-name}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.cluster-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.cluster-name
  }
}

resource "aws_security_group_rule" "cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster-sg.id
  source_security_group_id = aws_security_group.worker-sg.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-ingress-workstation-https" {
  cidr_blocks       = [local.workstation-external-cidr]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster-sg.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group_rule" "cluster-ingress-bastion-https" {
  description              = "Allow Bastion host to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster-sg.id
  source_security_group_id = aws_security_group.bastion-client-sg.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster-name
  role_arn = aws_iam_role.cluster-role.arn
  enabled_cluster_log_types = ["api","audit","authenticator","controllerManager","scheduler"]
#  version = 1.14

  vpc_config {
    security_group_ids = [aws_security_group.cluster-sg.id]
    subnet_ids         = aws_subnet.cluster-sn[*].id
    endpoint_private_access = true
    public_access_cidrs = var.cluster-api-public-access-cidrs
  }
  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
  ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
#  version                = "1.13.3"
  alias                  = "override"
}

#module "alb_ingress_controller" {
#  source = "iplabs/alb-ingress-controller/kubernetes"
#  version = "3.1.0"
#
#  providers = {
#    kubernetes = kubernetes.override
#  }
#  k8s_cluster_type = "eks"
#  k8s_namespace    = "kube-system"
#
#  aws_region_name  = data.aws_region.current.name
#  k8s_cluster_name = aws_eks_cluster.cluster.name
#  aws_tags = map(
#      "Name", "${var.cluster-name}-alb-ingress-controler",
#      "kubernetes.io/cluster/${var.cluster-name}", "owned",
#      "cluster-name", var.cluster-name
#	)
#}


