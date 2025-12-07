# ============================================================================
# Security Groups Configuration
# ============================================================================

# ============================================================================
# ALB Security Group (Application Load Balancer)
# ============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from anywhere (adjust in production)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow HTTPS from anywhere (adjust in production)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Type        = "alb"
  }
}

# ============================================================================
# EC2 Security Group (Application Instances)
# ============================================================================

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg-${var.environment}"
  description = "Security group for EC2 application instances"
  vpc_id      = aws_vpc.main.id

  # Allow application port from ALB only
  ingress {
    description     = "Application port from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

<<<<<<< HEAD
  # Allow SSH from VPC (adjust for production - should be more restrictive)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
=======
  # Allow SSH from admin IP only (RESTRICTED)
  ingress {
    description = "SSH from admin CIDRs only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
>>>>>>> master
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Type        = "ec2"
  }
}

# ============================================================================
# RDS Security Group (Database)
# ============================================================================

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg-${var.environment}"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  # Allow MySQL/PostgreSQL from EC2 instances and EKS nodes
  ingress {
    description     = "Database access from EC2 instances and EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [
      aws_security_group.ec2.id,
      aws_security_group.eks_nodes.id
    ]
  }

  # Allow PostgreSQL (if using PostgreSQL instead of MySQL)
  ingress {
    description     = "PostgreSQL access from EC2 instances and EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.ec2.id,
      aws_security_group.eks_nodes.id
    ]
  }

  # No outbound rules needed for RDS (it doesn't initiate connections)

  tags = {
    Name        = "${var.project_name}-rds-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Type        = "rds"
  }
}

# ============================================================================
# EKS Node SSH Access Security Group (for remote access to nodes)
# ============================================================================

resource "aws_security_group" "eks_nodes_ssh" {
  name        = "${var.project_name}-eks-nodes-ssh-sg-${var.environment}"
  description = "Security group for SSH access to EKS nodes"
  vpc_id      = aws_vpc.main.id

<<<<<<< HEAD
  # Allow SSH from VPC (adjust for production - should be more restrictive)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
=======
  # Allow SSH from admin IP only (RESTRICTED)
  ingress {
    description = "SSH from admin CIDRs only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
>>>>>>> master
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-eks-nodes-ssh-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Type        = "eks-nodes-ssh"
  }
}

<<<<<<< HEAD
=======
# ============================================================================
# VPC Endpoints Security Group (Missing from current setup)
# ============================================================================

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  # Allow HTTPS from private subnets
  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

>>>>>>> master
 