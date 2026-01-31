# 🚀 Full-Stack SaaS + Community Starter Kit

A complete, production-ready starter kit featuring:
- **Next.js** frontend with authentication
- **NestJS** backend API
- **Discourse** community forum
- **AWS infrastructure** as code (Terraform)
- **Single-command deployment**

## 🎯 TL;DR

**Local Development (30 seconds):**
```bash
cd dentia && ./dev.sh
```
Open http://localhost:3000 - **No AWS required!**

**AWS Deployment (1-2 hours):**
```bash
cp config.example.sh config.sh  # Fill in your values
./setup.sh                       # Choose [1] Full Setup
```
**Cost:** ~$150-200/month

📖 **Full guides:** `docs/LOCAL_DEVELOPMENT_GUIDE.md` & `docs/AWS_DEPLOYMENT_READINESS.md`

## ✨ What's Included

### Main Application (`dentia/`)
- Next.js 14+ with App Router
- AWS Cognito authentication
- PostgreSQL with Prisma ORM
- S3 file uploads
- Email notifications
- Multi-tenancy ready

### Community Forum (`dentiahub/`)
- Discourse (latest stable)
- Unified SSO with main app
- Docker containerized
- Custom plugins included
- Health monitoring

### Infrastructure (`*-infra/`)
- ECS Fargate for containers
- Aurora PostgreSQL Serverless v2
- ElastiCache Redis
- Application Load Balancer
- Cognito User Pool (shared)
- S3 buckets
- CloudWatch monitoring
- Auto-scaling configured

## 💰 Cost Estimate

**Minimal (~100 users):** ~$150-200/month
- ECS Fargate: ~$60/month
- Aurora: ~$30-60/month
- ElastiCache: ~$25/month
- ALB: ~$16/month
- S3 + misc: ~$20/month

## 🎯 Quick Start

### Prerequisites

**For Local Development:**
- **Docker** and Docker Compose
- **Node.js** >= 18 and pnpm

**For AWS Deployment:**
- **AWS Account** with admin access
- **AWS CLI** configured
- **Terraform** >= 1.6.0
- **Docker** and Docker Compose
- **Node.js** >= 18 and pnpm
- **Domain name** for your project

### Local Development (No AWS Required)

```bash
cd dentia

# Start all services (DB + Backend + Frontend)
./dev.sh

# Access your app
open http://localhost:3000
```

**That's it!** All services run locally via Docker and native processes.

📖 **See Development section below** for more options and details.

### 1. Clone and Configure

```bash
cd starter-kit

# Copy configuration template
cp config.example.sh config.sh

# Generate secrets
./scripts/generate-secrets.sh

# Edit config.sh with your values
nano config.sh
```

### 2. Configure Your Settings

Edit `config.sh` with your details:

```bash
# Required Settings
PROJECT_NAME="myproject"
AWS_PROFILE="myproject"
AWS_REGION="us-east-2"

APP_DOMAIN="app.example.com"
HUB_DOMAIN="hub.example.com"
APEX_DOMAIN="example.com"

# Fill in generated secrets
DB_MASTER_PASSWORD="..."
DISCOURSE_DB_PASSWORD="..."
NEXTAUTH_SECRET="..."
DISCOURSE_SSO_SECRET="..."

# SMTP for emails
SMTP_USERNAME="..."
SMTP_PASSWORD="..."
```

### 3. Run Setup

```bash
# Configure AWS credentials
aws configure --profile myproject

# Run the setup wizard
./setup.sh

# Choose option [1] Full Setup
```

### 4. Configure DNS

After deployment completes, point your domains to the ALB:

```bash
# Get ALB DNS from AWS Console or:
aws elbv2 describe-load-balancers \
  --names myproject-alb \
  --profile myproject \
  --region us-east-2
```

Create CNAME records:
- `app.example.com` → ALB DNS
- `hub.example.com` → ALB DNS

### 5. Access Your Apps

- **Main App:** https://app.example.com
- **Forum:** https://hub.example.com
- **API:** https://api.example.com

## 📋 Setup Wizard Options

The `./setup.sh` wizard provides:

1. **Full Setup** - Complete first-time installation (20-30 min)
2. **Deploy Infrastructure Only** - Just Terraform
3. **Deploy Applications Only** - Just Docker images
4. **Deploy Everything** - Infra + Apps
5. **Deploy Main App Only** - dentia only
6. **Deploy Forum Only** - dentiahub only
7. **Generate Secrets** - Create random passwords
8. **Validate Configuration** - Check your config

## 🏗️ Architecture

```
                    Internet
                       │
                       ▼
                ┌──────────────┐
                │ CloudFront   │ (Optional)
                └──────┬───────┘
                       │
                ┌──────▼───────┐
                │     ALB      │
                └──┬────────┬──┘
                   │        │
        ┌──────────┴──┐  ┌─▼──────────┐
        │   ECS App   │  │ ECS Forum  │
        │  (Frontend  │  │(Discourse) │
        │  + Backend) │  │            │
        └──┬────────┬─┘  └─┬──────────┘
           │        │      │
    ┌──────▼───┐ ┌─▼──────▼────┐ ┌────────┐
    │  Aurora  │ │   Redis     │ │   S3   │
    │PostgreSQL│ │(ElastiCache)│ │        │
    └──────────┘ └─────────────┘ └────────┘
           │
    ┌──────▼──────────┐
    │ Cognito (SSO)   │
    └─────────────────┘
```

## 🛠️ Customization

### Update Branding

**Main App:**
```bash
cd dentia/apps/frontend
# Update logo, colors, content
```

**Forum:**
```bash
cd dentiahub
# See BRANDING_CUSTOMIZATION.md
```

### Add Features

The codebase includes:
- Billing integration (Stripe-ready)
- Team management
- Role-based permissions
- Email templates
- Notification system

### Configure OAuth Providers

Add social login (Google, GitHub, etc.) in Cognito console.

## 📚 Documentation

### Getting Started
- **[Getting Started](GETTING_STARTED.md)** - 5-minute quick start for AWS deployment
- **[Local Development Guide](docs/LOCAL_DEVELOPMENT_GUIDE.md)** - Complete local dev guide
- **[AWS Deployment Readiness](docs/AWS_DEPLOYMENT_READINESS.md)** - Pre-deployment checklist

### Features
- **[Admin Impersonation Guide](docs/ADMIN_IMPERSONATION_GUIDE.md)** - Admin & super admin features
- **[Admin Quick Start](docs/ADMIN_IMPERSONATION_QUICK_START.md)** - Admin feature setup
- **[Monitoring & Auto-Scaling](docs/MONITORING_AUTOSCALING_SETUP.md)** - CloudWatch setup

### Operations
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and fixes
- **[Monitoring Quick Reference](docs/MONITORING_QUICK_REFERENCE.md)** - Monitoring commands
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture

### Component Documentation

- **Main App:** `dentia/README.md`
- **Main Infra:** `dentia-infra/README.md`
- **Forum:** `dentiahub/README.md`
- **Forum Infra:** `dentiahub-infra/README.md`

## 🔧 Development

### Local Development - Quick Start

The easiest way to run the full development environment:

```bash
cd dentia
./dev.sh
```

This single command starts:
- ✅ PostgreSQL database (Docker)
- ✅ LocalStack (S3 emulation)
- ✅ Backend (NestJS on port 4001)
- ✅ Frontend (Next.js on port 3000)

**Access URLs:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:4001
- Database: postgresql://dentia:dentia@localhost:5433/dentia

**Stop all services:** Press `Ctrl+C`

### Development Script Options

```bash
# Run everything (default)
./dev.sh

# Run only frontend (expects backend at localhost:4001)
./dev.sh -m frontend

# Run only backend
./dev.sh -m backend

# Run only database
./dev.sh -m db

# Use Docker for all services
./dev.sh --docker

# Skip dependency installation
./dev.sh -s

# Show help
./dev.sh --help
```

### What Runs in Each Mode

| Mode | Services | Use Case |
|------|----------|----------|
| `all` | PostgreSQL + LocalStack + Backend + Frontend | Full stack development (default) |
| `frontend` | PostgreSQL + Frontend | Frontend-only work (backend deployed elsewhere) |
| `backend` | PostgreSQL + LocalStack + Backend | Backend API development |
| `db` | PostgreSQL only | Database work, migrations |

### Service Logs

All logs are shown in your terminal AND saved to:
- `logs/backend.log` - Backend service logs
- `logs/frontend.log` - Frontend service logs

### Useful Development Commands

```bash
# Database client
psql postgresql://dentia:dentia@localhost:5433/dentia

# Prisma Studio (visual database editor)
cd packages/prisma && npx prisma studio

# View Docker containers
docker ps

# Stop all services (if dev.sh isn't responding)
./cleanup.sh

# Stop all + remove log files
./cleanup.sh --logs
```

### Manual Development (Alternative)

If you prefer to run services manually:

```bash
# Start database
cd dentia
docker-compose up -d postgres localstack

# Run migrations
cd packages/prisma
pnpm prisma migrate deploy
pnpm prisma generate

# Start backend (in one terminal)
cd apps/backend
pnpm install
pnpm start:dev

# Start frontend (in another terminal)
cd apps/frontend/apps/web
pnpm install
pnpm dev
```

### Forum Development

```bash
cd dentiahub
cp env.example .env
docker-compose up
```

### Testing

```bash
# Main App - Run all tests
cd dentia
pnpm test

# E2E tests
pnpm test:e2e

# Forum - Run plugin tests
cd dentiahub
./scripts/run-plugin-tests.sh
```

## 🚢 Deployment to AWS

### Is This Package Ready to Deploy? ✅ YES

The package is **production-ready** and can be deployed to a new AWS account with proper configuration.

**What's included:**
- ✅ Complete Terraform infrastructure
- ✅ Auto-scaling and monitoring
- ✅ Security best practices
- ✅ One-command deployment
- ✅ Database migrations

**What you need:**
- AWS account with admin access
- Domain name
- AWS SES setup for emails
- 30-45 minutes for first deployment

📖 **See:** `docs/AWS_DEPLOYMENT_READINESS.md` for complete checklist

### Quick Deployment (First Time)

```bash
# 1. Generate secrets
./scripts/generate-secrets.sh

# 2. Create configuration
cp config.example.sh config.sh
nano config.sh  # Fill in all values

# 3. Configure AWS CLI
aws configure --profile myproject

# 4. Run setup wizard
./setup.sh
# Choose [1] Full Setup

# 5. Configure DNS (point domains to ALB)
# 6. Test deployment
```

**Time:** 20-30 minutes (automated)  
**Cost:** ~$150-200/month for starter usage

### Deployment Modes

The `./setup.sh` wizard provides:

1. **Full Setup** - Complete first-time installation (recommended)
2. **Deploy Infrastructure Only** - Just Terraform resources
3. **Deploy Applications Only** - Just Docker images to existing infra
4. **Deploy Everything** - Infra + Apps (refresh deployment)
5. **Deploy Main App Only** - Update dentia application
6. **Deploy Forum Only** - Update dentiahub forum
7. **Generate Secrets** - Create random passwords
8. **Validate Configuration** - Check your config.sh

### Manual Deployment

```bash
# Deploy infrastructure
./scripts/deploy-infrastructure.sh

# Deploy applications
./scripts/deploy-applications.sh

# Or deploy individually
./scripts/deploy-dentia.sh
./scripts/deploy-dentiahub.sh
```

### CI/CD Setup (Optional)

The package **does not include** GitHub Actions or GitLab CI configurations.

**To add CI/CD:**
- See `docs/AWS_DEPLOYMENT_READINESS.md` for example workflows
- Set up secrets in your CI/CD platform
- Configure deployment triggers

### Post-Deployment Steps

1. **Configure DNS** - Point domains to ALB DNS name
2. **Verify SSL** - Wait for certificate validation (5-60 minutes)
3. **Test Services** - Check health endpoints
4. **Configure Discourse** - Set up OAuth2 integration
5. **Confirm Monitoring** - Subscribe to SNS email notifications

📖 **See:** `GETTING_STARTED.md` for step-by-step guide

## 🔐 Security

### Built-in Security Features

- ✅ Encryption at rest (RDS, Redis, S3)
- ✅ Encryption in transit (TLS/SSL)
- ✅ Private subnets for databases
- ✅ Security groups with least privilege
- ✅ IAM roles with minimal permissions
- ✅ Secrets in AWS SSM Parameter Store
- ✅ CORS configured properly
- ✅ Rate limiting enabled

### Security Checklist

- [ ] Rotate database passwords regularly
- [ ] Enable MFA for AWS account
- [ ] Review IAM policies quarterly
- [ ] Monitor CloudWatch alarms
- [ ] Keep dependencies updated
- [ ] Enable AWS GuardDuty
- [ ] Configure AWS WAF rules

## 📊 Monitoring

### CloudWatch Dashboards

- Application metrics (requests, errors, latency)
- Infrastructure metrics (CPU, memory, network)
- Database metrics (connections, queries)

### Logs

```bash
# Main app logs
aws logs tail /ecs/myproject-frontend --follow

# Forum logs
aws logs tail /ecs/dentiahub-production/discourse --follow
```

### Alarms

Pre-configured alarms for:
- High CPU/Memory usage
- Unhealthy targets
- 5xx error rates
- Database connection issues

## 🔄 Updates

### Update Main App

```bash
cd dentia
git pull
./scripts/deploy.sh
```

### Update Forum

```bash
cd dentiahub
git pull
./scripts/build-and-deploy-discourse.sh production
```

### Update Infrastructure

```bash
cd dentia-infra
terraform plan
terraform apply
```

## 🆘 Troubleshooting

### Common Issues

**Issue:** Deployment fails

```bash
# Check AWS credentials
aws sts get-caller-identity --profile myproject

# Check Terraform state
cd dentia-infra
terraform state list
```

**Issue:** Application won't start

```bash
# Check ECS tasks
aws ecs describe-services --cluster myproject-cluster

# Check logs
aws logs tail /ecs/myproject-frontend --follow
```

**Issue:** Database connection errors

```bash
# Verify security groups
aws ec2 describe-security-groups --profile myproject

# Test database connectivity from ECS
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more.

## 🤝 Contributing

This is a starter kit - make it your own! If you find bugs or have improvements, feel free to:

1. Fork the repository
2. Make your changes
3. Share your improvements

## 📄 License

- **Starter Kit Code:** MIT License
- **Discourse:** GPL v2 License
- **Next.js, NestJS:** MIT License

## 🙏 Acknowledgments

Built with:
- [Next.js](https://nextjs.org/) - React framework
- [NestJS](https://nestjs.com/) - Node.js framework
- [Discourse](https://www.discourse.org/) - Forum software
- [Terraform](https://www.terraform.io/) - Infrastructure as Code
- [AWS](https://aws.amazon.com/) - Cloud infrastructure

---

## 🎯 What's Next?

After setup completes:

1. ✅ **Verify Deployment** - Check all services are running
2. ✅ **Configure OAuth2** - Link Discourse to Cognito
3. ✅ **Customize Branding** - Add your logo, colors
4. ✅ **Set Up Monitoring** - Configure CloudWatch alarms
5. ✅ **Enable Backups** - Configure automated backups
6. ✅ **Add Team Members** - Invite your team
7. ✅ **Go Live!** - Launch your product

**Need help?** Check the documentation in `docs/` or review the component READMEs.

**Happy building!** 🚀

