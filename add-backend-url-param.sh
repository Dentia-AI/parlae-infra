#!/bin/bash

# Quick script to add just the BACKEND_API_URL parameter
# Use this if you want to test without full terraform deployment

set -e

PROFILE="dentia"
REGION="us-east-2"
BACKEND_URL="https://api.dentiaapp.com"

echo "Adding BACKEND_API_URL to SSM Parameter Store..."

aws ssm put-parameter \
  --name "/dentia/frontend/BACKEND_API_URL" \
  --value "$BACKEND_URL" \
  --type "String" \
  --overwrite \
  --profile "$PROFILE" \
  --region "$REGION"

echo "✅ Parameter added: $BACKEND_URL"
echo ""
echo "⚠️  NOTE: You still need to update the ECS task definition"
echo "   to reference this parameter. Options:"
echo ""
echo "   1. Run: cd infra/ecs && terraform apply"
echo "   2. Or manually update task definition in AWS Console"
echo ""
echo "   Then force a new deployment:"
echo "   aws ecs update-service --cluster dentia-cluster --service dentia-frontend --force-new-deployment --profile dentia --region us-east-2"

