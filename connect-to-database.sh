#!/usr/bin/env bash
set -euo pipefail

# Script to establish port forwarding tunnel to Aurora database via bastion
# Usage: ./connect-to-database.sh [aws-profile] [local-port]

PROFILE=${1:-parlae}
LOCAL_PORT=${2:-15432}
REGION="us-east-2"

echo "🔍 Finding bastion instance..."

# Find the bastion instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=parlae-bastion" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --profile "$PROFILE" \
  --region "$REGION" 2>/dev/null || echo "")

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "❌ ERROR: No running bastion instance found!"
  echo ""
  echo "Possible reasons:"
  echo "1. Instance is stopped - start it from AWS Console"
  echo "2. Instance doesn't exist - run 'terraform apply' in infra/ecs"
  echo "3. Wrong AWS profile - try: $0 <profile-name>"
  echo ""
  echo "To start the instance:"
  echo "  aws ec2 start-instances --instance-ids <instance-id> --profile $PROFILE --region $REGION"
  exit 1
fi

echo "✅ Found bastion: $INSTANCE_ID"

# Get the database endpoint from SSM or use default
DB_HOST=${DB_HOST:-parlae-aurora-cluster.cluster-cpe42k4icbjd.us-east-2.rds.amazonaws.com}
DB_PORT=5432

echo "🚀 Starting SSM port forwarding session..."
echo ""
echo "   Local:  localhost:$LOCAL_PORT"
echo "   Remote: $DB_HOST:$DB_PORT"
echo ""
echo "You can now connect using:"
echo "   psql -h localhost -p $LOCAL_PORT -U dentia_admin -d dentia"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$DB_HOST\"],\"portNumber\":[\"$DB_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
  --profile "$PROFILE" \
  --region "$REGION"

