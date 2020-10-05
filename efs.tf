resource "aws_efs_file_system" "cluster-efs" {
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
       Name = "${var.cluster-name}-efs"
   }
 }

resource "aws_security_group" "cluster-efs-sg" {
  name        = "${var.cluster-name}-efs-sg"
  description = "Security group for efs in the ${var.cluster-name} cluster"
  vpc_id      = aws_vpc.cluster-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    #kosab1 chaneg only to specific Ips
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = map(
     "Name", "${var.cluster-name}-efs-sg",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
}

resource "aws_efs_mount_target" "cluster-efs-mnt" {
  count = 2
  subnet_id      = aws_subnet.cluster-sn.*.id[count.index]
  file_system_id  = aws_efs_file_system.cluster-efs.id
  security_groups = [
    aws_security_group.cluster-efs-sg.id]
}