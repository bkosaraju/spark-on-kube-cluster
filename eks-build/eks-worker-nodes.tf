#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EC2 Security Group to allow networking traffic
#  * Data source to fetch latest EKS worker AMI
#  * AutoScaling Launch Configuration to configure worker instances
#  * AutoScaling Group to launch worker instances

resource "aws_iam_role" "cluster-worker-role" {
  name = "${var.cluster-name}-iam-worker-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "eks-autoscaleing-iam-policy" {
  name        = "${var.cluster-name}-autoscaling-iam-policy"
  path        = "/"
  description = "Policy for providing access Autoscale cluster for ${var.cluster-name} resources"

  policy = <<AUTOSCALE
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
AUTOSCALE
}

resource "aws_iam_role_policy_attachment" "eks-autoscale-iam-policy-attach" {
  role       = aws_iam_role.cluster-worker-role.name
  policy_arn = aws_iam_policy.eks-autoscaleing-iam-policy.arn
}


resource "aws_iam_role_policy_attachment" "cluster-worker-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.cluster-worker-role.name
}

resource "aws_iam_role_policy_attachment" "cluster-worker-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cluster-worker-role.name
}

resource "aws_iam_role_policy_attachment" "cluster-worker-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.cluster-worker-role.name
}

#resource "aws_iam_role_policy_attachment" "eks-argo-s3-iam-policy-attach" {
#  role       = aws_iam_role.cluster-worker-role.name
#  policy_arn = aws_iam_policy.argo-s3-config.arn
#}
#resource "aws_iam_role_policy_attachment" "eks-argo-kms-iam-policy-attach" {
#  role       = aws_iam_role.cluster-worker-role.name
#  policy_arn = aws_iam_policy.argo-kms-keyaccess.arn
#}


resource "aws_iam_instance_profile" "cluster-worker-profile" {
  name = "${var.cluster-name}-worker-instprof"
  role = aws_iam_role.cluster-worker-role.name
}

resource "aws_security_group" "worker-sg" {
  name        = "${var.cluster-name}-worker-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.cluster-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map(
     "Name", "${var.cluster-name}-sg",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
}

resource "aws_security_group_rule" "cluster-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.worker-sg.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.cluster-sg.id
  to_port                  = 65535
  type                     = "ingress"
}


data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  worker-userdata = <<USERDATA
#!/bin/bash
set -o xtrace

DEVICE=/dev/$(lsblk -n | awk '$NF != "/" {print $1}')
FS_TYPE=$(file -s $DEVICE | awk '{print $2}')
MOUNT_POINT=/data

# If no FS, then this output contains "data"
if [ "$FS_TYPE" = "data" ]
then
    echo "Creating file system on $DEVICE"
    mkfs -t ext4 $DEVICE
fi

mkdir $MOUNT_POINT
mount $DEVICE $MOUNT_POINT


/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_template" "worker-node-lt" {
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = var.worker-instance-type
  name_prefix                 = "${var.cluster-name}-worker"
  vpc_security_group_ids            = [aws_security_group.worker-sg.id]
  user_data            = base64encode(local.worker-userdata)
  key_name = aws_key_pair.bastin-client_key.id
  
  iam_instance_profile {
   name = aws_iam_instance_profile.cluster-worker-profile.name
  }

#ephemeral_block_device {
# device_name = "/dev/xvda"
#}

block_device_mappings {
  device_name = "/dev/xvda"
  no_device = true
  ebs {
    volume_type = "io1"
    volume_size = 300
    iops = 3000
  }
}
 
}



resource "aws_autoscaling_group" "worker-asg" {
  desired_capacity     = 1
#  launch_configuration  = aws_launch_configuration.worker-node-lc.id
  max_size             = var.worker-max-instances
  min_size             = 1
  name                 = "${var.cluster-name}-workers"
  vpc_zone_identifier   = aws_subnet.cluster-sn[*].id
  default_cooldown     = var.worker-instances-cooldown-duration
  launch_template {
    id      = aws_launch_template.worker-node-lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.cluster-name}-workers"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
   tag {
     key                 = "kubernetes.io/cluster/${var.cluster-name}"
     value               = "owned"
     propagate_at_launch = true
   }
   tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
   }
}
