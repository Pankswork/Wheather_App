# ============================================================================
# IAM Roles and Policies Configuration
# ============================================================================

# ============================================================================
# EC2 Instance Role (for EC2 instances to access AWS services)
# ============================================================================

resource "aws_iam_role" "ec2_instance" {
  name = "${var.project_name}-ec2-instance-role-${var.environment}-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-instance-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# EC2 Instance Profile (to attach role to EC2 instances)
# ============================================================================

resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${var.project_name}-ec2-instance-profile-${var.environment}"
  role = aws_iam_role.ec2_instance.name

  tags = {
    Name        = "${var.project_name}-ec2-instance-profile-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# EC2 SSM Policy (for Systems Manager access - allows SSH alternative)
# ============================================================================

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================================
# EC2 S3 Read Policy (for accessing S3 buckets)
# ============================================================================

resource "aws_iam_role_policy_attachment" "ec2_s3_read" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ============================================================================
# EC2 CloudWatch Agent Policy (for CloudWatch Logs and Metrics)
# ============================================================================

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ============================================================================
# Custom Policy for EC2 (Additional permissions as needed)
# ============================================================================

resource "aws_iam_role_policy" "ec2_custom" {
  name = "${var.project_name}-ec2-custom-policy-${var.environment}"
  role = aws_iam_role.ec2_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/ec2/${var.project_name}-${var.environment}*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# RDS Enhanced Monitoring Role (Optional - for RDS performance monitoring)
# ============================================================================

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-rds-monitoring-role-${var.environment}-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-rds-monitoring-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# Application Load Balancer Service Role (Managed by AWS)
# ============================================================================
# Note: ALB service role is automatically created by AWS
# This section documents the requirement but doesn't create it

# ============================================================================
# Lambda Execution Role (if using Lambda functions)
# ============================================================================

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role-${var.environment}-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-execution-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# EKS Cluster Autoscaler IAM Role (if enabled)
# ============================================================================

resource "aws_iam_role" "eks_cluster_autoscaler" {
  count = var.eks_enable_cluster_autoscaler ? 1 : 0
  name  = "${var.project_name}-eks-autoscaler-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-autoscaler-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "eks_cluster_autoscaler" {
  count = var.eks_enable_cluster_autoscaler ? 1 : 0
  name  = "${var.project_name}-eks-autoscaler-policy-${var.environment}"
  role  = aws_iam_role.eks_cluster_autoscaler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data source for AWS Account ID (for OIDC provider)
data "aws_caller_identity" "current" {}

