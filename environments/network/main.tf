# -----------------------------------------------------------------------------
# Networking Module - main.tf
#
# 这个文件是 networking 模块的核心，负责创建所有基础网络资源。
# 它是一个可复用的“组件”，通过接收变量来构建一套完整的网络环境。
# VPC：1

# NAT：1

# IGW：1

# public subnets：3

# private subnets：3

# public route table associations：3

# private route table associations：3

# public route table：1

# private route table：1

# EIP：1
# -----------------------------------------------------------------------------

# --- VPC (Virtual Private Cloud) ---
# 创建整个网络环境的顶层容器：VPC。
# 所有的子网、路由表、网关等资源都将存在于这个 VPC 内部。
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # 启用 DNS 主机名，这样在 VPC 内的实例可以通过 DNS 名称互相访问。
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- 互联网网关 (Internet Gateway) ---
# 创建互联网网关 (IGW)，并附加到我们的 VPC 上。
# IGW 是让 VPC 内的资源（特别是公有子网中的资源）能够访问互联网的唯一通道。
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- 公有子网 (Public Subnets) ---
# 创建公有子网。我们使用 count 和 length 函数，根据传入的 CIDR 列表动态创建所需数量的子网。
# 公有子网中的资源（如负载均衡器、堡垒机）可以直接与互联网通信。
resource "aws_subnet" "public" {
  count = length(var.public_subnets_cidr)

  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnets_cidr[count.index]
  # 将每个子网轮流放置在不同的可用区中，提高容灾能力。var.azs[count.index % var.az_count],但是这种写法并不主流。this approach is not really mainstream.
  availability_zone = var.azs[count.index]
  # 自动为在这个子网中启动的实例分配公有 IP 地址。
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- NAT 网关 (NAT Gateway) ---
# 为了让私有子网中的资源（如数据库、应用服务器）能够访问互联网（例如下载更新、调用外部 API），
# 但同时又不被互联网直接访问，我们需要一个 NAT 网关。

# 1. 首先，为 NAT 网关创建一个弹性 IP (EIP)，这是一个固定的公网 IP 地址。
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name        = "${var.project_name}-nat-eip"
    Project     = var.project_name
    Environment = var.environment
  }
}

# 2. 创建 NAT 网关本身，并将其放置在第一个公有子网中。
#    NAT 网关必须位于公有子网，因为它需要通过互联网网关与外界通信。
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-nat-gateway"
    Project     = var.project_name
    Environment = var.environment
  }

  # 明确依赖互联网网关，确保 IGW 创建完成后再创建 NAT 网关。
  depends_on = [aws_internet_gateway.igw]
}

# --- 私有子网 (Private Subnets) ---
# 创建私有子网。这些子网用于部署核心应用和数据存储，它们不能被互联网直接访问，更加安全。
resource "aws_subnet" "private" {
  count = length(var.private_subnets_cidr)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- 路由表 (Route Tables) ---
# 路由表决定了子网中的网络流量走向。我们需要为公有和私有子网分别创建路由规则。

# 1. 公有路由表：将所有去往互联网的流量 (0.0.0.0/0) 指向互联网网关 (IGW)。
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

# 2. 私有路由表：将所有去往互联网的流量 (0.0.0.0/0) 指向 NAT 网关。
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- 路由表关联 (Route Table Associations) ---
# 最后，将创建好的子网与对应的路由表进行绑定。

# 1. 将所有公有子网关联到公有路由表。
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 2. 将所有私有子网关联到私有路由表。
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
