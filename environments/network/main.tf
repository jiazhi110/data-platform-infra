# -----------------------------------------------------------------------------
# Networking Module - main.tf
# -----------------------------------------------------------------------------

# --- Virtual Private Cloud (VPC) ---
# Main network container for all project resources.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Enable internal DNS resolution.
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# --- Internet Gateway (IGW) ---
# Gateway for public internet access.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# --- Public Subnets ---
# Subnets with direct internet access via IGW.
resource "aws_subnet" "public" {
  count = length(var.public_subnets_cidr)

  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnets_cidr[count.index]
  # Distribute subnets across available zones.
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# --- NAT Gateway ---
# Allows resources in private subnets to reach the internet without incoming access.
# 1. Elastic IP for NAT Gateway.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# 2. NAT Gateway instance located in the first public subnet.
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# --- Private Subnets ---
# Isolated subnets for core applications and data services.
resource "aws_subnet" "private" {
  count = length(var.private_subnets_cidr)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# --- Route Tables ---
# 1. Public Route Table: Routes internet-bound traffic to IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 2. Private Route Table: Routes internet-bound traffic to NAT Gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# --- Route Table Associations ---
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- S3 Gateway Endpoint (Cost Optimization) ---
# Routes S3 traffic via the AWS internal network, bypassing NAT Gateway costs.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to private route table.
  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}