#!/bin/bash

# Deployment script for Weather App
# This script automates the deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOCKER_USERNAME="${DOCKERHUB_USERNAME:-}"
DOCKER_IMAGE="${DOCKER_IMAGE:-${DOCKER_USERNAME}/pythonapp}"
DOCKER_TAG="${DOCKER_TAG:-latest}"
TERRAFORM_DIR="terraform"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo -e "${GREEN}🚀 Weather App Deployment Script${NC}\n"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: docker is not installed${NC}" >&2; exit 1; }
    command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Error: terraform is not installed${NC}" >&2; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: aws cli is not installed${NC}" >&2; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is not installed${NC}" >&2; exit 1; }
    
    echo -e "${GREEN}✓ All prerequisites met${NC}\n"
}

# Build and push Docker image
build_and_push() {
    if [ -z "$DOCKER_USERNAME" ]; then
        echo -e "${YELLOW}DOCKERHUB_USERNAME not set. Skipping Docker build/push.${NC}"
        echo -e "${YELLOW}Set DOCKERHUB_USERNAME environment variable to build and push image.${NC}\n"
        return
    fi
    
    echo -e "${YELLOW}Building Docker image...${NC}"
    docker build -t "${DOCKER_IMAGE}:${DOCKER_TAG}" .
    docker tag "${DOCKER_IMAGE}:${DOCKER_TAG}" "${DOCKER_IMAGE}:latest"
    
    echo -e "${YELLOW}Pushing Docker image to Docker Hub...${NC}"
    docker push "${DOCKER_IMAGE}:${DOCKER_TAG}"
    docker push "${DOCKER_IMAGE}:latest"
    
    echo -e "${GREEN}✓ Docker image pushed: ${DOCKER_IMAGE}:${DOCKER_TAG}${NC}\n"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
    
    cd "$TERRAFORM_DIR"
    
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
    
    echo -e "${YELLOW}Planning Terraform deployment...${NC}"
    terraform plan -out=tfplan
    
    echo -e "${YELLOW}Applying Terraform configuration...${NC}"
    read -p "Do you want to proceed with deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Deployment cancelled${NC}"
        exit 0
    fi
    
    terraform apply tfplan
    
    echo -e "${GREEN}✓ Infrastructure deployed${NC}\n"
    
    cd ..
}

# Configure kubectl
configure_kubectl() {
    echo -e "${YELLOW}Configuring kubectl...${NC}"
    
    CLUSTER_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw eks_cluster_name 2>/dev/null || echo "pythonapp-cluster-dev")
    
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    
    echo -e "${GREEN}✓ kubectl configured${NC}\n"
}

# Add Weather API key secret
add_weather_api_key() {
    echo -e "${YELLOW}Setting up Weather API key...${NC}"
    
    if [ -z "$WEATHER_API_KEY" ]; then
        read -sp "Enter your Weather API key: " WEATHER_API_KEY
        echo
    fi
    
    NAMESPACE=$(cd "$TERRAFORM_DIR" && terraform output -raw kubernetes_namespace 2>/dev/null || echo "pythonapp-dev")
    
    kubectl create secret generic weather-api-key \
        --from-literal=WEATHER_API_KEY="$WEATHER_API_KEY" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Update deployment to use the secret
    kubectl set env deployment/pythonapp-app \
        WEATHER_API_KEY="$WEATHER_API_KEY" \
        -n "$NAMESPACE" || echo "Note: Deployment may not exist yet"
    
    echo -e "${GREEN}✓ Weather API key configured${NC}\n"
}

# Get application URL
get_app_url() {
    echo -e "${GREEN}📋 Deployment Summary${NC}\n"
    
    cd "$TERRAFORM_DIR"
    
    echo -e "Application URL:"
    terraform output -raw app_url 2>/dev/null || echo "Run 'terraform output app_url' to get the URL"
    
    echo -e "\nRDS Endpoint:"
    terraform output -raw rds_endpoint 2>/dev/null || echo "Run 'terraform output rds_endpoint' to get the endpoint"
    
    echo -e "\nEKS Cluster Name:"
    terraform output -raw eks_cluster_name 2>/dev/null || echo "Run 'terraform output eks_cluster_name' to get the cluster name"
    
    cd ..
}

# Main deployment flow
main() {
    check_prerequisites
    
    # Ask what to do
    echo "What would you like to do?"
    echo "1) Build and push Docker image only"
    echo "2) Deploy infrastructure only"
    echo "3) Full deployment (build, push, deploy)"
    echo "4) Configure kubectl only"
    echo "5) Add Weather API key only"
    read -p "Enter choice (1-5): " choice
    
    case $choice in
        1)
            build_and_push
            ;;
        2)
            deploy_infrastructure
            configure_kubectl
            ;;
        3)
            build_and_push
            deploy_infrastructure
            configure_kubectl
            add_weather_api_key
            get_app_url
            ;;
        4)
            configure_kubectl
            ;;
        5)
            configure_kubectl
            add_weather_api_key
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}✅ Deployment process completed!${NC}"
}

# Run main function
main


