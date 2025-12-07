# ============================================================================
# AWS GuardDuty Configuration - Threat Detection
# ============================================================================

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0
  enable = true

}

resource "aws_guardduty_detector_feature" "s3_logs" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.main[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.main[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"


}

# GuardDuty Publishing Destination for alerts
resource "aws_guardduty_publishing_destination" "main" {
  count = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.main[0].id
  destination_type = "S3"

  destination_arn  = aws_s3_bucket.guardduty_alerts[0].arn
  kms_key_arn      = aws_kms_key.guardduty[0].arn
}

resource "aws_s3_bucket" "guardduty_alerts" {
  count  = var.enable_guardduty ? 1 : 0
  bucket = "${var.project_name}-guardduty-alerts-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-guardduty-alerts-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_key" "guardduty" {
  count = var.enable_guardduty ? 1 : 0
  description             = "KMS key for GuardDuty alerts"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowGuardDuty"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-guardduty-kms-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}