#!/bin/bash

# Deploy Backend URL Fix
# This script adds the BACKEND_API_URL parameter and updates the frontend service

set -e

PROFILE="dentia"
REGION="us-east-2"
BACKEND_URL="https://api.dentiaapp.com"

echo "🚀 Deploying Backend URL Fix"
echo "=============================="
echo ""

# Step 1: Add SSM Parameter
echo "📝 Step 1: Adding BACKEND_API_URL to SSM Parameter Store"
aws ssm put-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --value "$BACKEND_URL" \
  --type "String" \
  --overwrite \
  --profile "$PROFILE" \
  --region "$REGION"

echo "✅ SSM parameter created/updated"
echo ""

# Step 2: Verify the parameter
echo "🔍 Step 2: Verifying SSM parameter"
PARAM_VALUE=$(aws ssm get-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --query 'Parameter.Value' \
  --output text \
  --profile "$PROFILE" \
  --region "$REGION")

echo "   BACKEND_API_URL = $PARAM_VALUE"
echo ""

# Step 3: Apply Terraform changes
echo "🏗️  Step 3: Applying Terraform changes"
cd infra/ecs
terraform init -upgrade
terraform plan
echo ""
read -p "Do you want to apply these Terraform changes? (yes/no): " APPLY

if [ "$APPLY" == "yes" ]; then
  terraform apply -auto-approve
  echo "✅ Terraform applied successfully"
else
  echo "⏭️  Skipping Terraform apply"
  echo ""
  echo "⚠️  NOTE: You must manually update the task definition to include BACKEND_API_URL"
  echo "   or run 'terraform apply' later to complete the deployment."
  exit 0
fi
echo ""

# Step 4: Force new deployment
echo "🔄 Step 4: Forcing new deployment of frontend service"
aws ecs update-service \
  --cluster dentia-cluster \
  --service dentia-frontend \
  --force-new-deployment \
  --profile "$PROFILE" \
  --region "$REGION" \
  > /dev/null

echo "✅ Deployment initiated"
echo ""

# Step 5: Wait for deployment to stabilize
echo "⏳ Step 5: Waiting for service to stabilize (this may take a few minutes)..."
aws ecs wait services-stable \
  --cluster dentia-cluster \
  --services dentia-frontend \
  --profile "$PROFILE" \
  --region "$REGION"

echo "✅ Service is stable"
echo ""

# Step 6: Verify
echo "🧪 Step 6: Testing backend connectivity"
echo "   Testing: https://api.dentiaapp.com/health"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.dentiaapp.com/health)

if [ "$HEALTH_STATUS" == "200" ]; then
  echo "✅ Backend health check passed (HTTP $HEALTH_STATUS)"
else
  echo "⚠️  Backend health check returned HTTP $HEALTH_STATUS"
fi
echo ""

echo "✅ Deployment Complete!"
echo ""
echo "Next Steps:"
echo "1. Log in to https://app.dentiaapp.com"
echo "2. Navigate to https://app.dentiaapp.com/home/test-api"
echo "3. Verify all backend tests pass"
echo ""
echo "To view logs:"
echo "  aws logs tail /ecs/dentia-frontend --follow --profile dentia --region us-east-2"

