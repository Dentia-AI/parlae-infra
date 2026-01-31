#!/usr/bin/env bash
set -euo pipefail

# Bastion SSM Fix Script
# Usage: ./fix-bastion-ssm.sh [instance-id] [aws-profile]

INSTANCE_ID=${1:-i-0eefd9be3ab9c483a}
PROFILE=${2:-dentia}
REGION="us-east-2"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 BASTION SSM FIX SCRIPT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Instance ID: $INSTANCE_ID"
echo "AWS Profile: $PROFILE"
echo "Region: $REGION"
echo ""

# Check if instance exists
echo "Checking instance state..."
STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text 2>/dev/null || echo "not-found")

if [[ "$STATE" == "not-found" ]]; then
  echo "❌ ERROR: Instance $INSTANCE_ID not found!"
  exit 1
fi

echo "Current state: $STATE"
echo ""

# If stopped, start it
if [[ "$STATE" == "stopped" ]]; then
  echo "Instance is stopped. Starting it now..."
  aws ec2 start-instances \
    --instance-ids "$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION"
  
  echo "Waiting for instance to start..."
  aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION"
  
  echo "✅ Instance started"
  echo ""
fi

# If running, do a stop/start cycle to apply user data
if [[ "$STATE" == "running" ]]; then
  echo "⚠️  Instance is running. A stop/start cycle will:"
  echo "   1. Apply the new user data (SSM agent setup)"
  echo "   2. Force SSM agent to reconnect"
  echo ""
  echo "This will cause ~2-3 minutes of downtime."
  echo ""
  read -p "Continue? (y/n) " -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    echo ""
    echo "Alternative: Wait 5 more minutes for SSM agent to connect naturally."
    exit 0
  fi
  
  echo ""
  echo "Stopping instance..."
  aws ec2 stop-instances \
    --instance-ids "$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION"
  
  echo "Waiting for instance to stop..."
  aws ec2 wait instance-stopped \
    --instance-ids "$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION"
  
  echo "✅ Instance stopped"
  echo ""
  
  echo "Starting instance..."
  aws ec2 start-instances \
    --instance-ids "$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION"
  
  echo "Waiting for instance to start..."
  aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION"
  
  echo "✅ Instance started"
  echo ""
fi

# Wait for SSM to connect
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ Waiting for SSM agent to connect..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This typically takes 2-3 minutes."
echo "Checking every 15 seconds..."
echo ""

MAX_ATTEMPTS=20
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  
  SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query "InstanceInformationList[0].PingStatus" \
    --output text 2>/dev/null || echo "NotRegistered")
  
  if [[ "$SSM_STATUS" == "Online" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SUCCESS! SSM agent is now ONLINE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "You can now connect to the database:"
    echo ""
    echo "   ./connect-to-database.sh"
    echo ""
    exit 0
  fi
  
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Status = $SSM_STATUS"
  
  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    sleep 15
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  TIMEOUT: SSM agent did not connect after 5 minutes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Possible issues:"
echo "1. No internet connectivity (check public IP, IGW, route table)"
echo "2. IAM role missing SSM permissions"
echo "3. Security group blocking outbound traffic"
echo "4. SSM agent failed to start (check system log)"
echo ""
echo "Next steps:"
echo ""
echo "1. Check system log:"
echo "   aws ec2 get-console-output --instance-id $INSTANCE_ID --profile $PROFILE --region $REGION --output text | tail -50"
echo ""
echo "2. Check if instance has public IP:"
echo "   aws ec2 describe-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress'"
echo ""
echo "3. Review IAM instance profile:"
echo "   aws ec2 describe-instances --instance-ids $INSTANCE_ID --profile $PROFILE --region $REGION --query 'Reservations[0].Instances[0].IamInstanceProfile'"
echo ""
echo "4. Run diagnostics:"
echo "   ./diagnose-bastion.sh"
echo ""
exit 1

