# Base network for the environment (DNS support is enabled so resources can resolve names cleanly)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

# Gives the VPC a path to the internet for public-facing services.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# Public subnets hold front-end or internet-facing workloads that need a public IP.
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # resources are reachable from the internet by default
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public-${var.availability_zones[count.index]}"

    "kubernetes.io/role/elb"                                  = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
  }
}

# private subnets keep internal workloads off the public internet
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # resources stay private and do not get a public IP
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-${var.environment}-private-${var.availability_zones[count.index]}"

    "kubernetes.io/role/internal-elb"                         = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
  }

  lifecycle {
    ignore_changes = [tags["karpenter.sh/discovery"]]
  }
}

# static IPs for NAT gateways so private subnets can reach the internet without exposing their own IPs
resource "aws_eip" "eip" {
  domain = "vpc"
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)

  tags = {
    Name = "${var.project}-${var.environment}-nat-eip-${var.availability_zones[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT gateways provide outbound internet access for private subnets per AZ
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  count         = var.single_nat_gateway ? 1 : length(var.availability_zones)

  tags = {
    Name = "${var.project}-${var.environment}-nat-gateway-${var.availability_zones[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# public route table sends outbound traffic to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    "Name" = "${var.project}-${var.environment}-public-rt"
  }
}

# private route table sends internet-bound traffic through NAT for each AZ
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  count  = length(var.availability_zones)

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
  }

  tags = {
    "Name" = "${var.project}-${var.environment}-private-rt-${var.availability_zones[count.index]}"
  }
}

# attach each public subnet to the shared public route table
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# attach each private subnet to its matching NAT-backed route table
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
