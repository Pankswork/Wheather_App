# ============================================================================
# RDS MySQL Database Configuration
# ============================================================================

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db-${var.environment}"

  # Engine configuration
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage > 0 ? var.db_max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = coalesce(var.db_password, random_password.db_password.result)
  port     = var.db_port

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false
  multi_az                = var.db_multi_az
  performance_insights_enabled = false

  # Backup configuration
  backup_retention_period = var.db_backup_retention_period
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window

  # Monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval            = 60
  monitoring_role_arn            = aws_iam_role.rds_enhanced_monitoring.arn

  # Lifecycle
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.project_name}-db-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"



  tags = {
    Name        = "${var.project_name}-db-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_db_subnet_group.main,
    aws_security_group.rds
  ]
}

# Generate random password if not provided
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store DB credentials in AWS Secrets Manager (optional but recommended)
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}-db-credentials-${var.environment}-v3"

  tags = {
    Name        = "${var.project_name}-db-credentials-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = coalesce(var.db_password, random_password.db_password.result)
    engine   = var.db_engine
    host     = aws_db_instance.main.address
    port     = var.db_port
    dbname   = var.db_name
  })

  depends_on = [aws_db_instance.main]
}

