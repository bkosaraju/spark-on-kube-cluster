resource "aws_subnet" "cluster-nat-sn" {
  cidr_block = var.vpc_az_cidrs_public
  vpc_id            = aws_vpc.cluster-vpc.id

  tags = map(
  "Name", "${var.cluster-name}-subnet-nat",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_route_table" "cluster-public-rt" {
  vpc_id = aws_vpc.cluster-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster-igw.id
  }

  tags = map(
  "Name", "${var.cluster-name}-rtb-nat",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_route_table_association" "cluster-rt-association-public" {
  subnet_id      = aws_subnet.cluster-nat-sn.id
  route_table_id = aws_route_table.cluster-public-rt.id
}

resource "aws_eip" "cluster-nat-gw-eip" {
  vpc = true
  tags = map(
  "Name", "${var.cluster-name}-nat-eip",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}


resource "aws_nat_gateway" "cluster-nat-gw" {
  allocation_id = aws_eip.cluster-nat-gw-eip.id
  subnet_id     = aws_subnet.cluster-nat-sn.id

  tags = map(
  "Name", "${var.cluster-name}-nat-gw",
  "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}
