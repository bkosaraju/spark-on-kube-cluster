
//TODO: Update Key
variable "bastian_public_key" {
  default = ""
}
resource "aws_key_pair" "bastin-client_key" {
  key_name   = "${var.cluster-name}-bastion-key"
  public_key = var.bastion_public_key
  tags = map(
  "Name", "${var.cluster-name}-bastion-key",
  "kubernetes.io/cluster/${var.cluster-name}", "owned",
  )
}

resource "aws_security_group" "bastion-client-sg" {
  name        = "${var.cluster-name}-bastion-sg"
  description = "Security group for bastion host in the ${var.cluster-name} cluster"
  vpc_id      = aws_vpc.cluster-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Bastion host to ssh to VPC nodes"
  }

  ingress {
    from_port = 2049
    protocol = "tcp"
    to_port = 2049
    security_groups = [aws_security_group.cluster-efs-sg.id]
    description = "NFS Connectivity to EFS filesystem ${aws_efs_file_system.cluster-efs.id}}"
  }

  tags = map(
     "Name", "${var.cluster-name}-bastion-sg",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
}


resource "aws_instance" "bastion-client" {
  count             = 1
  ami               = "ami-0b8b10b5bf11f3a22"
  instance_type     = var.bastion-instance-type
  monitoring        = "false"
  key_name          = aws_key_pair.bastin-client_key.key_name
  subnet_id         = aws_subnet.cluster-nat-sn.id
  security_groups   = [aws_security_group.bastion-client-sg.id,aws_security_group.cluster-efs-sg.id]
  associate_public_ip_address = true
  user_data_base64 = base64encode(local.bastion-client)
  tags = map(
  "Name", "${var.cluster-name}-bastion-host",
  "kubernetes.io/cluster/${var.cluster-name}", "owned",
  )
}

//allow All security connection to worker nodes from Bastion network.

resource "aws_security_group_rule" "cluster-node-ingress-bastion" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.bastion-client-sg.id
  to_port                  = 65535
  type                     = "ingress"
}

//resource "aws_efs_mount_target" "bastin_efs_mnt" {
//  file_system_id = aws_efs_file_system.cluster-efs.id
//  subnet_id = aws_subnet.cluster-nat-sn.id
//  security_groups = [aws_security_group.cluster-efs-sg.id]
//}



locals {
  bastion-client = <<USERDATA
#!/bin/bash
set -o xtrace
curl -o /tmp/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
curl -o /tmp/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator
chmod +x /tmp/kubectl /tmp/eksctl /tmp/aws-iam-authenticator
mv /tmp/kubectl /tmp/eksctl /tmp/aws-iam-authenticator /usr/local/bin
yum install java-openjdk -y
#yum install -y amazon-efs-utils
#mkdir /efs
#efs_id='${aws_efs_file_system.cluster-efs.dns_name}'
#mount -t efs $efs_id:/ /efs
#echo $efs_id:/ /efs efs defaults,_netdev 0 0 >> /etc/fstab
USERDATA
}