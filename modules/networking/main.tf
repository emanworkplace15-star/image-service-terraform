# VPC "image" and everything network-related:
#   - public + private subnets across two AZs
#   - IGW for public ingress, single NAT gateway for private egress
#     (dev workload; an S3 gateway endpoint additionally keeps S3 traffic
#     off the NAT bill)
#   - least-privilege security groups: alb -> app -> db

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # app SG accepts traffic only from the ALB, DB SG only from the app SG.
}

# ---------------- VPC ----------------

resource "aws_vpc" "image" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.image.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

# ---------------- Subnets ----------------

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.image.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, count.index) # 10.0.0.0/19, 10.0.32.0/19
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.vpc_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id                  = aws_vpc.image.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, count.index + var.az_count) # 10.0.64.0/19, 10.0.96.0/19
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-${count.index + 1}"
  })
}

# ---------------- Routing ----------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.image.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Single NAT gateway in AZ 1 (dev: cost > multi-AZ NAT redundancy; the app
# instance itself lives in AZ 1 so its egress path has no cross-AZ hop).
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.image.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# S3 gateway endpoint: image-object traffic (presigned PUT/GET, Lambda reads
# and writes) goes through it free of NAT data-processing charges.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.image.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.public.id]

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-s3-endpoint"
  })
}

data "aws_region" "current" {}

# ---------------- Security groups ----------------

resource "aws_security_group" "alb" {
  name_prefix = "${var.vpc_name}-alb-"
  description = "Public ALB: HTTPS/HTTP from the world."
  vpc_id      = aws_vpc.image.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere (reserved for when an ACM cert lands)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-alb"
  })
}

resource "aws_security_group" "app" {
  name_prefix = "${var.vpc_name}-app-"
  description = "App instances: only the ALB may reach the container ports."
  vpc_id      = aws_vpc.image.id

  ingress {
    description     = "Backend container port from ALB"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Frontend container port from ALB"
    from_port       = var.frontend_port
    to_port         = var.frontend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from within the VPC only (SSM is the usual access path)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-app"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.vpc_name}-rds-"
  description = "Database: only the app SG may reach Postgres."
  vpc_id      = aws_vpc.image.id

  ingress {
    description     = "Postgres from app instances only"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-rds"
  })
}