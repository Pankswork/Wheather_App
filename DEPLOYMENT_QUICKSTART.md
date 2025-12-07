# 🚀 Quick Start Deployment Checklist

Use this checklist for a fast deployment to AWS.

## ✅ Pre-Deployment Checklist

- [ ] AWS account created and AWS CLI configured (`aws configure`)
- [ ] Terraform installed (`terraform version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Docker installed and running
- [ ] Docker Hub account created
- [ ] Weather API key obtained from https://www.weatherapi.com/
- [ ] AWS EC2 Key Pair created (for EKS node access)

## 📝 Configuration Steps

### 1. Update Terraform Variables
Edit `terraform/terraform.tfvars`:
```hcl
docker_image = "YOUR_DOCKERHUB_USERNAME/pythonapp"
db_password = "YourSecurePassword123!"
key_name = "your-aws-key-pair-name"
```

### 2. Push Docker Image
```bash
docker build -t YOUR_DOCKERHUB_USERNAME/pythonapp:latest .
docker login
docker push YOUR_DOCKERHUB_USERNAME/pythonapp:latest
```

## 🚀 Deployment Options

### Option A: Automated Script (Recommended)
```bash
export DOCKERHUB_USERNAME=your-username
export WEATHER_API_KEY=your-api-key
./deploy.sh
# Choose option 3 for full deployment
```

### Option B: Manual Steps
```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name pythonapp-cluster-dev

# 3. Add Weather API key
cd ..
./update-weather-api-key.sh YOUR_API_KEY

# 4. Get application URL
cd terraform
terraform output app_url
```

## 🔍 Verify Deployment

```bash
# Check pods are running
kubectl get pods -n pythonapp-dev

# Check services
kubectl get svc -n pythonapp-dev

# Check ingress (ALB)
kubectl get ingress -n pythonapp-dev

# View logs
kubectl logs -f deployment/pythonapp-app -n pythonapp-dev
```

## 🔗 Access Your App

After deployment completes (15-20 minutes), get your URL:
```bash
cd terraform
terraform output app_url
```

Visit the URL in your browser!

## 🆘 Common Issues

**Pods not starting?**
- Check logs: `kubectl logs <pod-name> -n pythonapp-dev`
- Verify Docker image exists and is accessible
- Check database connection

**Can't access ALB?**
- Wait 2-3 minutes after ingress creation
- Check security groups allow HTTP traffic
- Verify ingress: `kubectl get ingress -n pythonapp-dev`

**Database connection errors?**
- Verify RDS endpoint: `terraform output rds_endpoint`
- Check security groups allow traffic from EKS nodes
- Verify credentials in Kubernetes secret

## 📚 Full Documentation

For detailed instructions, troubleshooting, and advanced configuration, see [DEPLOYMENT.md](./DEPLOYMENT.md)










