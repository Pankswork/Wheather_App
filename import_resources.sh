#!/bin/bash
cd terraform
# Initialize Terraform
terraform init

# Use MSYS_NO_PATHCONV=1 to prevent Git Bash from converting /aws/... paths to C:/Program Files/...
export MSYS_NO_PATHCONV=1

echo "Importing missing CloudWatch Log Groups..."
terraform import aws_cloudwatch_log_group.eks_cluster /aws/eks/pythonapp-cluster-dev/cluster
terraform import aws_cloudwatch_log_group.vpc_flow_logs[0] /aws/vpc/flow-logs/pythonapp-dev

echo "Import complete!"
