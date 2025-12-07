# 🔐 Managing Sensitive Values in Terraform

## ❌ DO NOT Hardcode Passwords in terraform.tfvars

Even though `terraform.tfvars` is in `.gitignore`, it's a security risk to hardcode passwords.

## ✅ Recommended Approaches

### Option 1: Environment Variables (Best for CI/CD)

Set sensitive values as environment variables with `TF_VAR_` prefix:

```bash
# Local development
export TF_VAR_db_username="admin"
export TF_VAR_db_password="your-secure-password"
terraform apply
```

**For CI/CD (GitHub Actions):**
- Store secrets in GitHub Secrets: `Settings → Secrets and variables → Actions`
- Add these secrets:
  - `DB_USERNAME`
  - `DB_PASSWORD`
- The CI/CD workflow will automatically use them (see `.github/workflows/ci-cd.yml`)

### Option 2: AWS Secrets Manager (Best for Production)

1. Store secrets in AWS Secrets Manager
2. Terraform retrieves them automatically
3. No secrets in code or environment variables

### Option 3: Local terraform.tfvars (Only for Local Dev)

**ONLY if:**
- ✅ File is in `.gitignore` (it is)
- ✅ You're working locally only
- ✅ You never commit it

**Still not recommended** - use environment variables instead.

## 📋 Required GitHub Secrets

Add these in your GitHub repository:
- `DB_USERNAME` - RDS database username
- `DB_PASSWORD` - RDS database password
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key

## 🚀 Quick Setup

1. **Remove hardcoded password from terraform.tfvars:**
   ```bash
   # Edit terraform.tfvars and set:
   db_password = ""  # Leave empty
   ```

2. **For local development, use environment variables:**
   ```bash
   export TF_VAR_db_password="your-password"
   terraform apply
   ```

3. **For CI/CD, add GitHub Secrets** (already configured in workflow)

## ✅ Current Setup

Your CI/CD workflow (`.github/workflows/ci-cd.yml`) is already configured to use:
- `TF_VAR_db_username` from `secrets.DB_USERNAME`
- `TF_VAR_db_password` from `secrets.DB_PASSWORD`

Just add these secrets in GitHub and you're good to go!


