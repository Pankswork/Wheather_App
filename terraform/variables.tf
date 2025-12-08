# ============================================================================
# Common Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "pythonapp"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ============================================================================
# VPC Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Subnet configuration with CIDR and AZ
variable "public_subnets" {
  description = "List of public subnets with CIDR and AZ"
  type = list(object({
    cidr = string
    az   = string
  }))
  default = [
    {
      cidr = "10.0.1.0/24"
      az   = "us-east-1a"
    },
    {
      cidr = "10.0.2.0/24"
      az   = "us-east-1b"
    }
  ]
}

variable "private_subnets" {
  description = "List of private subnets with CIDR and AZ"
  type = list(object({
    cidr = string
    az   = string
  }))
  default = [
    {
      cidr = "10.0.11.0/24"
      az   = "us-east-1a"
    },
    {
      cidr = "10.0.12.0/24"
      az   = "us-east-1b"
    }
  ]
}

variable "database_subnets" {
  description = "List of database subnets with CIDR and AZ"
  type = list(object({
    cidr = string
    az   = string
  }))
  default = [
    {
      cidr = "10.0.21.0/24"
      az   = "us-east-1a"
    },
    {
      cidr = "10.0.22.0/24"
      az   = "us-east-1b"
    }
  ]
}

# ============================================================================
# Security Group Variables (for sg.tf)
# ============================================================================

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources (e.g., ALB)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ⚠️ Change this to your specific IP ranges in production
}

variable "app_port" {
  description = "Port on which the application runs"
  type        = number
  default     = 5000
}

# ============================================================================
# EC2 Variables (for ec2.tf)
# ============================================================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "AWS Key Pair name for EC2 instances"
  type        = string
  default     = "DemoInstance"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty to use latest Amazon Linux)"
  type        = string
  default     = ""
}

# ============================================================================
# RDS Variables (for rds.tf)
# ============================================================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS maximum allocated storage for autoscaling (0 to disable)"
  type        = number
  default     = 100
}

variable "db_engine" {
  description = "RDS database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "RDS database engine version"
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "pythonapp"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_port" {
  description = "RDS database port"
  type        = number
  default     = 3306
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 0
}

variable "db_backup_window" {
  description = "RDS backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "RDS maintenance window"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "db_multi_az" {
  description = "Enable RDS multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when deleting RDS instance"
  type        = bool
  default     = true
}

# ============================================================================
# EKS Variables (for eks.tf)
# ============================================================================

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.30"
}

variable "docker_image" {
  description = "Docker image URI (from Docker Hub or ECR)"
  type        = string
  default     = ""
}

variable "docker_image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 4
}

variable "eks_node_disk_size" {
  description = "Disk size for EKS nodes in GB"
  type        = number
  default     = 20
}

variable "eks_node_capacity_type" {
  description = "Capacity type for EKS nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler for EKS"
  type        = bool
  default     = true
}

variable "k8s_replicas" {
  description = "Number of replicas for Kubernetes deployment"
  type        = number
  default     = 2
}

# ============================================================================
# ALB Variables (for alb.tf)
# ============================================================================

variable "alb_enable_https" {
  description = "Enable HTTPS listener for ALB"
  type        = bool
  default     = false
}

variable "alb_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS (required if alb_enable_https is true)"
  type        = string
  default     = ""
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 60
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

# ============================================================================
# Security Variables
# ============================================================================

variable "admin_cidr_blocks" {
  description = "CIDR blocks for administrative access (SSH, etc.)"
  type        = list(string)
  default     = ["172.27.12.93/32"]  # Your IP
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention period for VPC Flow Logs"
  type        = number
  default     = 7  # Project scope
}

variable "enable_network_acls" {
  description = "Enable Network ACLs for additional security layer"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection"
  type        = bool
  default     = false
}

# ============================================================================
# Monitoring Variables (Prometheus/Grafana)
# ============================================================================

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "598684"
}

variable "alert_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = "pankajshakya12345@gmail.com"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size in GB"
  type        = number
  default     = 50
}

variable "prometheus_retention_days" {
  description = "Prometheus metrics retention in days"
  type        = number
  default     = 7  # Project scope
}

variable "grafana_storage_size" {
  description = "Grafana storage size in GB"
  type        = number
  default     = 10
}

