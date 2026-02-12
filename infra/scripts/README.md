# Infrastructure Scripts

This directory contains scripts for managing AWS infrastructure secrets and configurations.

## Scripts Overview

### `put-ssm-secrets.sh`

Uploads all production secrets to AWS Systems Manager (SSM) Parameter Store.

**Usage:**
```bash
./put-ssm-secrets.sh [aws-profile] [region]
```

**Defaults:**
- Profile: `dentia`
- Region: `us-east-2`

**What it does:**
- Uploads database connection strings
- Configures Cognito settings
- Sets up Stripe production keys
- Configures GoHighLevel integration keys
- Creates parameters under `/dentia/shared/*`, `/dentia/frontend/*`, `/dentia/backend/*`

**Example:**
```bash
./put-ssm-secrets.sh dentia us-east-2
```

**Prerequisites:**
- AWS CLI installed and configured
- Valid AWS credentials for the dentia profile
- node (for encoding database passwords)

---

### `put-ssm-secrets-dev.sh`

Uploads all dev environment secrets to AWS SSM Parameter Store **AFTER** Terraform has been applied.

**Usage:**
```bash
./put-ssm-secrets-dev.sh [aws-profile] [terraform-dir]
```

**Defaults:**
- Profile: `dentia`
- Terraform directory: `infra/environments/dev`

**What it does:**
- Reads Terraform outputs from dev environment (Aurora endpoint, S3 bucket, etc.)
- Generates dev-specific secrets (NEXTAUTH_SECRET, etc.)
- Uploads Stripe test keys
- Configures all platform API keys for dev
- Creates parameters under `/dentia/dev/*`

**Example:**
```bash
./put-ssm-secrets-dev.sh dentia infra/environments/dev
```

**Environment Variable Overrides:**
- `DEV_NEXTAUTH_SECRET`: Override the generated NextAuth secret
- `DEV_DISCOURSE_SSO_SECRET`: Override the generated Discourse SSO secret
- `DEV_HOSTNAME_OVERRIDE`: Override the ALB hostname

**Prerequisites:**
- AWS CLI installed and configured
- **Terraform outputs must exist** (run `terraform apply` first)
- jq, node, openssl installed

**When to use:**
- When dev infrastructure is already deployed and running
- When you want secrets to match actual Terraform-created resources

---

### `put-ssm-secrets-dev-standalone.sh` ⭐ NEW

Uploads all dev environment secrets to AWS SSM Parameter Store **WITHOUT** requiring Terraform to be deployed.

**Usage:**
```bash
./put-ssm-secrets-dev-standalone.sh [aws-profile] [region]
```

**Defaults:**
- Profile: `dentia`
- Region: `us-east-2`

**What it does:**
- Uses placeholder/default values for infrastructure resources
- Generates dev-specific secrets (NEXTAUTH_SECRET, etc.)
- Uploads Stripe test keys
- Configures all platform API keys for dev
- Creates parameters under `/dentia/dev/*`
- Secrets persist even when dev infrastructure is destroyed

**Example:**
```bash
./put-ssm-secrets-dev-standalone.sh dentia us-east-2
```

**Environment Variable Overrides:**
- `DEV_HOSTNAME`: Override dev hostname (default: `dev.parlae.ca`)
- `DEV_NEXTAUTH_SECRET`: Override the generated NextAuth secret
- `DEV_DISCOURSE_SSO_SECRET`: Override the generated Discourse SSO secret
- `DEV_S3_BUCKET`: Override S3 bucket name
- `DEV_AURORA_ENDPOINT`: Override Aurora endpoint
- `DEV_COGNITO_USER_POOL_ID`: Override Cognito pool ID
- And more...

**Prerequisites:**
- AWS CLI installed and configured
- node, openssl installed
- **NO Terraform required!**

**When to use:**
- **Recommended for ephemeral dev environments** that are destroyed after testing
- When you want to upload secrets before deploying infrastructure
- When dev infrastructure doesn't exist yet
- When you want secrets to persist across multiple deploy/destroy cycles

**Workflow:**
```bash
# 1. Upload secrets once (persist in SSM)
./put-ssm-secrets-dev-standalone.sh

# 2. Deploy dev infrastructure when needed
cd infra/environments/dev
terraform apply

# 3. Test your changes
# ...

# 4. Destroy infrastructure (secrets remain in SSM)
terraform destroy

# 5. Next time, just run terraform apply (secrets already there)
terraform apply
```

---

## Platform API Keys

Both scripts configure the following platform integrations:

### GoHighLevel
- `GHL_API_KEY`
- `GHL_LOCATION_ID`
- `NEXT_PUBLIC_GHL_WIDGET_ID`
- `NEXT_PUBLIC_GHL_LOCATION_ID`
- `NEXT_PUBLIC_GHL_CALENDAR_ID`

---

## SSM Parameter Naming Convention

### Production
```
/dentia/
├── shared/              # Shared across services
│   ├── AWS_REGION
│   ├── S3_BUCKET
│   ├── COGNITO_*
│   ├── STRIPE_*
│   └── [PLATFORM]_*
├── frontend/            # Frontend-specific
│   ├── NEXTAUTH_*
│   ├── COGNITO_*
│   ├── DATABASE_URL
│   └── BACKEND_API_URL
└── backend/             # Backend-specific
    ├── DATABASE_URL
    ├── AWS_REGION
    ├── S3_BUCKET
    ├── COGNITO_*
    └── [PLATFORM]_*
```

### Dev Environment
Same structure but under `/dentia/dev/*` prefix.

---

## Common Workflows

### Initial Setup (Production)

1. Upload all secrets:
   ```bash
   ./put-ssm-secrets.sh
   ```

2. Verify secrets were created:
   ```bash
   aws ssm get-parameters-by-path \
     --path /dentia/ \
     --recursive \
     --profile dentia \
     --region us-east-2 \
     | jq '.Parameters[].Name'
   ```

### Update a Single Secret

```bash
aws ssm put-parameter \
  --name /dentia/backend/DATABASE_URL \
  --value "new-secret-value" \
  --type SecureString \
  --overwrite \
  --profile dentia \
  --region us-east-2
```

Then force ECS service redeployment:
```bash
aws ecs update-service \
  --cluster dentia-prod \
  --service dentia-prod-backend \
  --force-new-deployment \
  --profile dentia \
  --region us-east-2
```

### Rotate All Secrets

1. Update secret values in the script
2. Run the script to update SSM:
   ```bash
   ./put-ssm-secrets.sh
   ```
3. Redeploy services:
   ```bash
   cd ../ecs
   terraform apply
   ```

### View a Secret

```bash
aws ssm get-parameter \
  --name /dentia/backend/META_APP_SECRET \
  --with-decryption \
  --profile dentia \
  --region us-east-2 \
  | jq -r '.Parameter.Value'
```

### List All Parameters

```bash
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=/dentia/" \
  --profile dentia \
  --region us-east-2
```

---

## Security Notes

1. **Never commit these scripts with real secrets** to public repositories
2. **Use SecureString type** for all sensitive values
3. **Audit access regularly** using CloudTrail
4. **Rotate secrets** at least quarterly
5. **Limit IAM permissions** to only what's needed

---

## Troubleshooting

### Error: "aws CLI is required"
```bash
# Install AWS CLI
brew install awscli  # macOS
# or follow: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
```

### Error: "node is required"
```bash
# Install Node.js
brew install node  # macOS
# or download from: https://nodejs.org/
```

### Error: "jq is required" (dev script only)
```bash
# Install jq
brew install jq  # macOS
```

### Error: "Unable to read Terraform outputs"
```bash
# Make sure Terraform is applied
cd ../environments/dev
terraform apply
```

### Parameter Already Exists
The scripts use `--overwrite` flag, so they should succeed even if parameters exist. If you get an error:
```bash
# Check if parameter exists
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Option=Equals,Values=/dentia/backend/DATABASE_URL" \
  --profile dentia
```

---

## Related Documentation

- [Platform API Keys Documentation](../../docs/PLATFORM_API_KEYS.md)
- [AWS SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [ECS Secrets Management](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-parameters.html)

