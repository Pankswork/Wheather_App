# ============================================================================
# Application Load Balancer Configuration
# ============================================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_http2               = true
  idle_timeout               = var.alb_idle_timeout

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
    prefix  = "alb-logs"
  }

  tags = {
    Name        = "${var.project_name}-alb-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# ALB Target Group
# ============================================================================

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg-${var.environment}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-tg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# ALB Listeners
# ============================================================================

# HTTP Listener (redirects to HTTPS if HTTPS is enabled)
resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.alb_enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.alb_enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.alb_enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.app.arn
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-alb-listener-http-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# HTTPS Listener (if HTTPS is enabled)
resource "aws_lb_listener" "app_https" {
  count = var.alb_enable_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name        = "${var.project_name}-alb-listener-https-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# S3 Bucket for ALB Access Logs
# ============================================================================

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-alb-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-alb-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# ============================================================================
# S3 Bucket Policy for ALB Access Logs
# ============================================================================

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# ============================================================================
# Data Source for AWS Account ID
# ============================================================================
# ============================================================================
# Data Source for AWS Account ID
# ============================================================================
# NOTE: Moved to iam.tf to avoid duplicate resource

data "aws_elb_service_account" "main" {}

