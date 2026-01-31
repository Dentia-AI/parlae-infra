# Backend API URL Configuration Fix

## Issue
The frontend service was unable to connect to the backend service, resulting in "fetch failed" errors when accessing `/home/test-api` or any other backend API endpoints. The root cause was that the `BACKEND_API_URL` environment variable was not configured in the frontend ECS task definition.

## What Was Fixed

### 1. Infrastructure Changes
- **File**: `infra/ecs/services.tf`
  - Added `BACKEND_API_URL` to the frontend task definition secrets

### 2. SSM Parameter Scripts Updated
- **File**: `infra/scripts/put-ssm-secrets.sh` (Production)
  - Added `BACKEND_API_URL` parameter: `https://api.dentiaapp.com`

- **File**: `infra/scripts/put-ssm-secrets-dev.sh` (Dev)
  - Added `BACKEND_API_URL` parameter: `https://api.${DOMAIN}` (e.g., `https://api.dentia.ca`)

## Deployment Steps

### Step 1: Add SSM Parameter (Production)

Run this command to add the BACKEND_API_URL parameter to SSM:

```bash
aws ssm put-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --value "https://api.dentiaapp.com" \
  --type "String" \
  --profile dentia \
  --region us-east-2 \
  --overwrite
```

Or run the full script (will update all parameters):

```bash
cd ~/Projects/Dentia/dentia-infra/infra/scripts
./put-ssm-secrets.sh
```

### Step 2: Update Task Definition

The task definition needs to be updated to reference the new SSM parameter. You have two options:

#### Option A: Apply Terraform Changes (Recommended)

```bash
cd ~/Projects/Dentia/dentia-infra/infra/ecs
terraform plan
terraform apply
```

This will create a new task definition revision with the BACKEND_API_URL secret.

#### Option B: Manual AWS Console Update

1. Go to ECS Console → Task Definitions → `dentia-frontend`
2. Create new revision
3. Add a new secret:
   - **Name**: `BACKEND_API_URL`
   - **Value from**: `arn:aws:ssm:us-east-2:ACCOUNT_ID:parameter/dentia/frontend/BACKEND_API_URL`
4. Create the new revision

### Step 3: Update the ECS Service

Force a new deployment with the updated task definition:

```bash
aws ecs update-service \
  --cluster dentia-cluster \
  --service dentia-frontend \
  --force-new-deployment \
  --profile dentia \
  --region us-east-2
```

### Step 4: Verify the Deployment

Monitor the deployment:

```bash
aws ecs wait services-stable \
  --cluster dentia-cluster \
  --services dentia-frontend \
  --profile dentia \
  --region us-east-2
```

Check the logs to verify the service started successfully:

```bash
aws logs tail /ecs/dentia-frontend --follow --profile dentia --region us-east-2
```

### Step 5: Test Backend Connectivity

1. Log in to the application at `https://app.dentiaapp.com`
2. Navigate to `https://app.dentiaapp.com/home/test-api`
3. Verify that all backend tests pass:
   - ✅ Backend status check
   - ✅ Echo test
   - ✅ Database test
   - ✅ Frontend API routes
   - ✅ Browser-to-backend communication

## How It Works

### Architecture
```
Browser → CloudFront → ALB
                        ├─ app.dentiaapp.com/* → Frontend Service
                        └─ api.dentiaapp.com/* → Backend Service
```

### Frontend-to-Backend Communication
```
Frontend Server
  ↓ (uses BACKEND_API_URL=https://api.dentiaapp.com)
ALB
  ↓ (routes api.dentiaapp.com to backend target group)
Backend Service
```

The frontend makes server-side requests to the backend using the public API URL (`https://api.dentiaapp.com`), which routes through the ALB to the backend service.

## Alternative: Internal ALB Communication (Future Optimization)

For better performance and security, you could configure the frontend to call the backend through the internal ALB DNS name instead of the public URL:

```bash
# Get the internal ALB DNS name
aws elbv2 describe-load-balancers \
  --names dentia-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --profile dentia \
  --region us-east-2

# Example: internal-dentia-alb-123456789.us-east-2.elb.amazonaws.com
```

Then update the BACKEND_API_URL to use HTTP with the internal ALB DNS:

```bash
aws ssm put-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --value "http://internal-dentia-alb-XXXXX.us-east-2.elb.amazonaws.com" \
  --type "String" \
  --overwrite \
  --profile dentia \
  --region us-east-2
```

However, this requires:
1. Updating the backend listener rules to accept requests without the `api.dentiaapp.com` host header
2. Or setting up AWS Cloud Map service discovery
3. Adjusting security groups if needed

For now, using the public API URL is simpler and works fine.

## Rollback

If you need to rollback:

1. Revert to the previous task definition:
   ```bash
   aws ecs update-service \
     --cluster dentia-cluster \
     --service dentia-frontend \
     --task-definition dentia-frontend:PREVIOUS_REVISION \
     --force-new-deployment \
     --profile dentia \
     --region us-east-2
   ```

2. Remove the SSM parameter (optional):
   ```bash
   aws ssm delete-parameter \
     --name "/dentia/frontend/BACKEND_API_URL" \
     --profile dentia \
     --region us-east-2
   ```

## Verification Commands

### Check SSM Parameter
```bash
aws ssm get-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --profile dentia \
  --region us-east-2
```

### Check Current Task Definition
```bash
aws ecs describe-task-definition \
  --task-definition dentia-frontend \
  --profile dentia \
  --region us-east-2 \
  --query 'taskDefinition.containerDefinitions[0].secrets' \
  --output table
```

### Check Running Tasks
```bash
aws ecs list-tasks \
  --cluster dentia-cluster \
  --service-name dentia-frontend \
  --profile dentia \
  --region us-east-2
```

### Test Backend Connection (from local machine)
```bash
# Test the backend directly
curl -I https://api.dentiaapp.com/health

# Should return 200 OK
```

## Summary

This fix ensures that the Next.js frontend server can communicate with the NestJS backend by providing the proper backend API URL through environment variables. The frontend was falling back to `http://localhost:4000` which doesn't exist in the ECS container environment, causing all backend API calls to fail.

