# Quick Fix Summary: Backend API Connection

## Problem
- ✅ Login works perfectly
- ❌ Backend API calls fail with "fetch failed"
- Root cause: Frontend doesn't know where the backend is located

## Solution
Added `BACKEND_API_URL` environment variable to the frontend service pointing to `https://api.dentiaapp.com`

## Files Changed

### 1. Infrastructure
- `infra/ecs/services.tf` - Added BACKEND_API_URL secret to frontend task definition

### 2. Deployment Scripts
- `infra/scripts/put-ssm-secrets.sh` - Added BACKEND_API_URL for production
- `infra/scripts/put-ssm-secrets-dev.sh` - Added BACKEND_API_URL for dev

## Quick Deploy (Recommended)

Run the automated deployment script:

```bash
cd ~/Projects/Dentia/dentia-infra
./deploy-backend-url-fix.sh
```

This will:
1. Add the SSM parameter
2. Apply Terraform changes
3. Deploy the updated task definition
4. Wait for the service to stabilize
5. Test backend connectivity

## Manual Deploy (Alternative)

If you prefer to do it manually:

```bash
# 1. Add SSM parameter
aws ssm put-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --value "https://api.dentiaapp.com" \
  --type "String" \
  --overwrite \
  --profile dentia \
  --region us-east-2

# 2. Apply Terraform
cd ~/Projects/Dentia/dentia-infra/infra/ecs
terraform apply

# 3. Force new deployment
aws ecs update-service \
  --cluster dentia-cluster \
  --service dentia-frontend \
  --force-new-deployment \
  --profile dentia \
  --region us-east-2

# 4. Wait for stability
aws ecs wait services-stable \
  --cluster dentia-cluster \
  --services dentia-frontend \
  --profile dentia \
  --region us-east-2
```

## Verification

After deployment, test the API connection:

1. Go to https://app.dentiaapp.com/home/test-api
2. All tests should pass:
   - ✅ Backend status check
   - ✅ Echo test
   - ✅ Database test
   - ✅ Frontend API routes
   - ✅ Browser-to-backend communication

## What This Fixes

Before:
```
Frontend tries to call: http://localhost:4000/
Result: fetch failed (localhost doesn't exist in container)
```

After:
```
Frontend calls: https://api.dentiaapp.com/
ALB routes to: Backend service
Result: Success! ✅
```

## Estimated Time
- Automated script: ~5-10 minutes (including deployment stabilization)
- Manual deployment: ~5-10 minutes

## Need Help?

See `BACKEND_URL_FIX.md` for detailed documentation including:
- Architecture diagrams
- Alternative configurations
- Rollback procedures
- Troubleshooting tips

