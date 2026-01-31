##########################################
# Networking — fixed and working version #
##########################################

# Fetch AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags_common, {
    Name = "${local.project_id}-vpc"
  })
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags_common, {
    Name = "${local.project_id}-igw"
  })
}

# ---------- Public subnets ----------
resource "aws_subnet" "public" {
  for_each = {
    a = {
      cidr = var.public_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    b = {
      cidr = var.public_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags = merge(local.tags_common, {
    Name = "${local.project_id}-public-${each.key}"
    Tier = "public"
  })
}

# ---------- Private subnets ----------
resource "aws_subnet" "private" {
  for_each = {
    a = {
      cidr = var.private_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    b = {
      cidr = var.private_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = merge(local.tags_common, {
    Name = "${local.project_id}-private-${each.key}"
    Tier = "private"
  })
}

# ---------- Routes ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags_common, {
    Name = "${local.project_id}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------- Security Groups ----------
resource "aws_security_group" "alb" {
  name        = "${local.project_id}-alb-sg"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "${local.project_id}-ecs-sg"
  description = "ECS Tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${local.project_id}-db-sg"
  description = "Aurora DB SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
