#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table

variable "enable_dns_hostnames" {
  description = "should be true if you want to use private DNS within the VPC"
  default     = true
}

variable "enable_dns_support" {
  description = "should be true if you want to use private DNS within the VPC"
  default     = true
}

resource "aws_vpc" "cluster-vpc" {
  cidr_block = var.vpc_cidr_blocks
  
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  tags = map(
      "Name", "${var.cluster-name}-vpc",
      "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
}

resource "aws_subnet" "cluster-sn" {
  count = var.vpc_az_count
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block = var.vpc_az_cidrs_private[count.index]
  vpc_id            = aws_vpc.cluster-vpc.id

  tags = map(
      "Name", "${var.cluster-name}-subnet",
      "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
}

resource "aws_internet_gateway" "cluster-igw" {
  vpc_id = aws_vpc.cluster-vpc.id
  tags = {
    Name = var.cluster-name
  }
}

resource "aws_route_table" "cluster-rt" {
  vpc_id = aws_vpc.cluster-vpc.id

//  route {
//    cidr_block = "0.0.0.0/0"
//    gateway_id = aws_internet_gateway.cluster-igw.id
//  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.cluster-nat-gw.id
  }
  tags = map(
  "Name", "${var.cluster-name}-rtb",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_route_table_association" "cluster-rt-association" {
  count = var.vpc_az_count
  subnet_id      = aws_subnet.cluster-sn.*.id[count.index]
  route_table_id = aws_route_table.cluster-rt.id
}
