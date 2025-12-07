# 🚀 Deployment Guide

This guide will help you deploy your Weather App to AWS using EKS (Elastic Kubernetes Service).

## 📋 Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** installed (>= 1.0)
   ```bash
   terraform version
   ```
4. **kubectl** installed
   ```bash
   kubectl version --client
   ```
5. **Docker** installed and running
6. **Docker Hub account** (or AWS ECR) for storing images
7. **Weather API Key** from https://www.weatherapi.com/

## 🎯 Deployment Steps

### Step 1: Push Docker Image to Docker Hub

1. **Build and tag your Docker image:**
   ```bash
   docker build -t your-dockerhub-username/pythonapp:latest .
   ```

2. **Login to Docker Hub:**
   ```bash
   docker login
   ```

3. **Push the image:**
   ```bash
   docker push your-dockerhub-username/pythonapp:latest
   ```

   > **Note:** Replace `your-dockerhub-username` with your actual Docker Hub username.

### Step 2: Configure Terraform Variables

1. **Navigate to terraform directory:**
   ```bash
   cd terraform
   ```

2. **Update `terraform.tfvars` with your values:**
   ```hcl
   # Update these critical values:
   docker_image = "your-dockerhub-username/pythonapp"  # Your Docker Hub image
   db_password = "YourSecurePassword123!"              # Strong password for RDS
   key_name = "your-aws-key-pair-name"                # Your AWS EC2 key pair
   ```

3. **For production, also update:**
   ```hcl
   environment = "prod"
   db_multi_az = true
   db_deletion_protection = true
   db_skip_final_snapshot = false
   allowed_cidr_blocks = ["YOUR_IP/32"]  # Restrict access
   ```

### Step 3: Initialize and Deploy Infrastructure

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Review the deployment plan:**
   ```bash
   terraform plan
   ```

3. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```
   
   Type `yes` when prompted. This will create:
   - VPC with subnets
   - RDS MySQL database
   - EKS cluster with node groups
   - Application Load Balancer
   - Security groups
   - Kubernetes deployment and service

   ⏱️ **This process takes 15-20 minutes** (EKS cluster creation is slow).

### Step 4: Configure kubectl

After Terraform completes, configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name pythonapp-cluster-dev
```

Verify connection:
```bash
kubectl get nodes
kubectl get pods -n pythonapp-dev
```

### Step 5: Add Weather API Key to Kubernetes

The database credentials are already in Kubernetes secrets, but you need to add the Weather API key:

```bash
kubectl create secret generic weather-api-key \
  --from-literal=WEATHER_API_KEY=your_weather_api_key_here \
  -n pythonapp-dev
```

Then update the Kubernetes deployment to use this secret. You can do this by editing the deployment:

```bash
kubectl edit deployment pythonapp-app -n pythonapp-dev
```

Add this to the `env` section of the container spec:
```yaml
- name: WEATHER_API_KEY
  valueFrom:
    secretKeyRef:
      name: weather-api-key
      key: WEATHER_API_KEY
```

Or use the provided script (see below).

### Step 6: Get Application URL

After deployment, get your application URL:

```bash
terraform output app_url
```

Or get the ALB DNS name:
```bash
terraform output alb_dns_name
```

Visit the URL in your browser: `http://<alb-dns-name>`

## 🔄 Updating the Application

### Update Docker Image

1. **Make your code changes**

2. **Build and push new image:**
   ```bash
   docker build -t your-dockerhub-username/pythonapp:v1.1 .
   docker push your-dockerhub-username/pythonapp:v1.1
   ```

3. **Update Kubernetes deployment:**
   ```bash
   kubectl set image deployment/pythonapp-app \
     pythonapp-app=your-dockerhub-username/pythonapp:v1.1 \
     -n pythonapp-dev
   ```

4. **Check rollout status:**
   ```bash
   kubectl rollout status deployment/pythonapp-app -n pythonapp-dev
   ```

### Using Terraform to Update Image

Alternatively, update `terraform.tfvars`:
```hcl
docker_image_tag = "v1.1"
```

Then:
```bash
terraform apply
```

## 🛠️ Useful Commands

### Check Application Status
```bash
# Check pods
kubectl get pods -n pythonapp-dev

# Check services
kubectl get svc -n pythonapp-dev

# Check ingress
kubectl get ingress -n pythonapp-dev

# View logs
kubectl logs -f deployment/pythonapp-app -n pythonapp-dev
```

### Database Access
```bash
# Get RDS endpoint
terraform output rds_endpoint

# Connect to database (from a pod or bastion host)
mysql -h <rds-endpoint> -u admin -p
```

### Scale Application
```bash
# Scale manually
kubectl scale deployment pythonapp-app --replicas=3 -n pythonapp-dev

# Or update terraform.tfvars and run terraform apply
k8s_replicas = 3
```

## 🧹 Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

⚠️ **Warning:** This will delete all resources including the database and all data!

## 🔐 Security Best Practices

1. **Never commit secrets** - Use AWS Secrets Manager or Kubernetes secrets
2. **Use HTTPS** - Set up SSL certificate and enable HTTPS in ALB
3. **Restrict access** - Update `allowed_cidr_blocks` to your IP ranges
4. **Enable RDS backups** - Set `db_skip_final_snapshot = false` for production
5. **Use strong passwords** - Generate secure passwords for database
6. **Enable Multi-AZ** - Set `db_multi_az = true` for production
7. **Enable deletion protection** - Set `db_deletion_protection = true` for production

## 🐛 Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n pythonapp-dev
kubectl logs <pod-name> -n pythonapp-dev
```

### Database connection issues
- Check RDS security group allows traffic from EKS nodes
- Verify database credentials in Kubernetes secret
- Check RDS endpoint is correct

### ALB not accessible
- Check ALB security group allows HTTP traffic
- Verify ingress is created: `kubectl get ingress -n pythonapp-dev`
- Check ALB target group health

### Image pull errors
- Verify Docker image exists and is public (or configure ECR access)
- Check image name and tag in terraform.tfvars
- Verify EKS nodes have permission to pull images

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

