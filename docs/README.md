# 📚 Dentia Infrastructure Documentation

Documentation for the Dentia infrastructure and Terraform configurations.

---

## 🏗️ Infrastructure Overview

This repository contains the Terraform infrastructure-as-code for Dentia's AWS deployment.

### Main Components

- **ECS Cluster**: Container orchestration
- **Aurora PostgreSQL**: Database
- **ALB & CloudFront**: Load balancing and CDN
- **Bastion Host**: Secure database access
- **WAF**: Web application firewall
- **Cognito**: User authentication

---

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured
- Terraform installed
- Proper AWS credentials

### Deploy Infrastructure

```bash
cd infra/ecs
terraform init
terraform plan
terraform apply
```

### Connect to Database

```bash
./connect-to-database.sh
```

### Access Bastion Host

```bash
# Via SSM (recommended)
aws ssm start-session --target <bastion-instance-id>

# Diagnose bastion issues
./diagnose-bastion.sh
```

---

## 📁 Repository Structure

```
dentia-infra/
├── infra/
│   ├── ecs/              # Main ECS infrastructure
│   │   ├── acm_alb.tf    # Load balancer & certificates
│   │   ├── aurora.tf     # Database configuration
│   │   ├── bastion.tf    # Bastion host
│   │   ├── cluster.tf    # ECS cluster
│   │   ├── cognito.tf    # User pools
│   │   ├── services.tf   # ECS services
│   │   └── ...
│   ├── environments/     # Environment-specific configs
│   │   └── dev/
│   └── scripts/          # Deployment scripts
├── docs/
│   └── archive/          # Historical troubleshooting docs
└── *.sh                  # Utility scripts
```

---

## 📜 Available Scripts

### Database Access

| Script | Description |
|--------|-------------|
| `connect-to-database.sh` | Connect to Aurora PostgreSQL via bastion |
| `diagnose-bastion.sh` | Diagnose bastion host issues |
| `fix-bastion-ssm.sh` | Fix SSM connectivity issues |

### Deployment

| Script | Description |
|--------|-------------|
| `add-backend-url-param.sh` | Add BACKEND_URL parameter |
| `deploy-backend-url-fix.sh` | Deploy backend URL configuration |

---

## 🔧 Common Tasks

### Deploy New Environment

```bash
cd infra/ecs
terraform workspace new staging
terraform plan -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

### Update ECS Service

```bash
cd infra/ecs
terraform plan -target=aws_ecs_service.backend
terraform apply -target=aws_ecs_service.backend
```

### Add SSM Parameters

```bash
cd infra/scripts
./put-ssm-secrets-dev.sh  # For dev environment
./put-ssm-secrets.sh      # For production
```

### Run Database Migrations

```bash
cd infra/scripts
./deploy-migrations-local.sh                        # Local
./deploy-production-migrations-run-from-dentia.sh   # Production
```

---

## 🔐 Security

### Secrets Management

All secrets are stored in AWS Systems Manager Parameter Store:

- Database credentials
- API keys
- Cognito configuration
- Application secrets

**Never commit secrets to this repository!**

### Access Control

- Bastion host uses SSM Session Manager (no SSH keys)
- IAM roles for service-to-service communication
- Security groups restrict network access
- WAF protects against common attacks

---

## 🗂️ Archive

Historical troubleshooting and fix documentation has been moved to [`archive/`](archive/):

- Bastion host fixes and improvements
- Backend URL configuration fixes
- Quick fix summaries

See [`archive/README.md`](archive/README.md) for details.

---

## 📊 Infrastructure Resources

### Production Environment

- **ECS Cluster**: dentia-cluster
- **Database**: Aurora PostgreSQL (Serverless v2)
- **Load Balancer**: Application Load Balancer + CloudFront
- **Bastion**: t3.micro instance with SSM
- **Region**: us-east-2 (primary)

### Monitoring

- CloudWatch logs for all services
- ECS service metrics
- ALB metrics
- Database performance insights

---

## 🛠️ Terraform Commands

### Common Operations

```bash
# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy resources (careful!)
terraform destroy

# Show current state
terraform show

# List resources
terraform state list

# Import existing resource
terraform import aws_instance.bastion i-1234567890
```

### Workspaces

```bash
# List workspaces
terraform workspace list

# Create workspace
terraform workspace new staging

# Switch workspace
terraform workspace select production

# Show current workspace
terraform workspace show
```

---

## 📝 Configuration Files

### Main Terraform Files

| File | Purpose |
|------|---------|
| `acm_alb.tf` | SSL certificates and load balancer |
| `alb_targets.tf` | Target groups for services |
| `aurora.tf` | Database cluster configuration |
| `bastion.tf` | Bastion host setup |
| `cloudfront_waf.tf` | CDN and firewall |
| `cluster.tf` | ECS cluster |
| `cognito.tf` | User authentication |
| `ecr.tf` | Container registry |
| `iam.tf` | IAM roles and policies |
| `networking.tf` | VPC, subnets, security groups |
| `services.tf` | ECS services definitions |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |

### Variable Files

- `terraform.tfvars` - Main configuration
- `variables.tf` - Variable definitions

---

## 🚨 Troubleshooting

### Bastion Host Issues

See archived documentation:
- [`archive/BASTION_FIX_QUICK_START.md`](archive/BASTION_FIX_QUICK_START.md)
- [`archive/BASTION_IMPROVEMENTS.md`](archive/BASTION_IMPROVEMENTS.md)

Or use the diagnostic script:
```bash
./diagnose-bastion.sh
```

### Backend URL Configuration

See: [`archive/BACKEND_URL_FIX.md`](archive/BACKEND_URL_FIX.md)

### General Fixes

See: [`archive/QUICK_FIX_SUMMARY.md`](archive/QUICK_FIX_SUMMARY.md)

---

## 🔄 CI/CD Integration

### GitHub Actions

The main application repository (dentia) has GitHub Actions workflows that:

1. Build Docker images
2. Push to ECR
3. Update ECS services
4. Run database migrations

See the main repo's `.github/workflows/` for details.

---

## 📞 Getting Help

### Documentation

- **This README**: Infrastructure overview and common tasks
- **Archive**: Historical issues and fixes
- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

### Common Issues

1. **Can't connect to bastion**: Run `./diagnose-bastion.sh`
2. **Database connection failed**: Check security groups and secrets
3. **ECS service won't start**: Check CloudWatch logs
4. **Terraform state locked**: Check DynamoDB for locks

---

## 🎯 Best Practices

### Infrastructure Changes

1. ✅ Always run `terraform plan` first
2. ✅ Review changes carefully
3. ✅ Test in dev environment first
4. ✅ Use workspaces for environments
5. ✅ Commit state file changes
6. ✅ Document significant changes

### Security

1. ✅ Never commit secrets
2. ✅ Use SSM Parameter Store
3. ✅ Rotate credentials regularly
4. ✅ Use least-privilege IAM policies
5. ✅ Enable CloudTrail logging
6. ✅ Review security group rules

### Cost Optimization

1. ✅ Use Fargate Spot for non-critical workloads
2. ✅ Right-size Aurora instance
3. ✅ Clean up unused resources
4. ✅ Use CloudWatch for monitoring
5. ✅ Set up billing alerts

---

## 📈 Monitoring

### CloudWatch Dashboards

Access via AWS Console:
- ECS Cluster metrics
- Service CPU/Memory
- ALB request metrics
- Database performance

### Logs

```bash
# View ECS service logs
aws logs tail /ecs/dentia-backend --follow

# View bastion logs
aws logs tail /var/log/bastion --follow
```

---

## 🔗 Related Repositories

- **dentia**: Main application code
- **dentia-infra**: This repository (infrastructure)

---

**Last Updated**: November 14, 2024  
**Terraform Version**: 1.5+  
**AWS Provider Version**: 5.0+

