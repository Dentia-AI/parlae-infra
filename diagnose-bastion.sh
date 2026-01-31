#!/usr/bin/env bash
set -euo pipefail

# Bastion Diagnostic Script
# Usage: ./diagnose-bastion.sh [instance-id] [aws-profile]

INSTANCE_ID=${1:-i-0eefd9be3ab9c483a}
PROFILE=${2:-dentia}
REGION="us-east-2"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 BASTION DIAGNOSTIC REPORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Instance ID: $INSTANCE_ID"
echo "AWS Profile: $PROFILE"
echo "Region: $REGION"
echo ""

# Check 1: Instance State
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 CHECK 1: Instance State"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
INSTANCE_INFO=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0]" \
  2>/dev/null || echo "null")

if [[ "$INSTANCE_INFO" == "null" ]]; then
  echo "❌ ERROR: Instance not found!"
  exit 1
fi

STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
INSTANCE_TYPE=$(echo "$INSTANCE_INFO" | jq -r '.InstanceType')
PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress // "None"')
PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress')
LAUNCH_TIME=$(echo "$INSTANCE_INFO" | jq -r '.LaunchTime')
SUBNET_ID=$(echo "$INSTANCE_INFO" | jq -r '.SubnetId')

echo "State:         $STATE"
echo "Instance Type: $INSTANCE_TYPE"
echo "Public IP:     $PUBLIC_IP"
echo "Private IP:    $PRIVATE_IP"
echo "Subnet:        $SUBNET_ID"
echo "Launch Time:   $LAUNCH_TIME"

if [[ "$STATE" != "running" ]]; then
  echo ""
  echo "⚠️  WARNING: Instance is not running!"
  echo "   Current state: $STATE"
  exit 1
fi

if [[ "$PUBLIC_IP" == "None" ]]; then
  echo ""
  echo "⚠️  WARNING: No public IP address!"
  echo "   SSM agent needs internet access to register."
fi

echo "✅ Instance is running"
echo ""

# Check 2: IAM Instance Profile
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 CHECK 2: IAM Instance Profile"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
IAM_PROFILE=$(echo "$INSTANCE_INFO" | jq -r '.IamInstanceProfile.Arn // "None"')
echo "IAM Profile: $IAM_PROFILE"

if [[ "$IAM_PROFILE" == "None" ]]; then
  echo "❌ ERROR: No IAM instance profile attached!"
  echo "   SSM requires AmazonSSMManagedInstanceCore policy."
  exit 1
fi
echo "✅ IAM profile is attached"
echo ""

# Check 3: Security Group
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 CHECK 3: Security Group (Egress Rules)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SG_IDS=$(echo "$INSTANCE_INFO" | jq -r '.SecurityGroups[].GroupId' | tr '\n' ' ')
echo "Security Groups: $SG_IDS"

for SG_ID in $SG_IDS; do
  echo ""
  echo "Checking $SG_ID egress rules..."
  aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query "SecurityGroups[0].IpPermissionsEgress[].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]" \
    --output table 2>/dev/null || echo "Could not retrieve rules"
done

echo ""
echo "✅ Security group configured (check above for egress to 0.0.0.0/0)"
echo ""

# Check 4: SSM Connection Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔌 CHECK 4: SSM Connection Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SSM_INFO=$(aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "InstanceInformationList[0]" \
  2>/dev/null || echo "null")

if [[ "$SSM_INFO" == "null" || "$SSM_INFO" == "" ]]; then
  echo "❌ ERROR: Instance NOT registered with SSM!"
  echo ""
  echo "Possible reasons:"
  echo "1. SSM agent not running"
  echo "2. No internet connectivity (check public IP and NAT/IGW)"
  echo "3. IAM role missing SSM permissions"
  echo "4. Instance just started (wait 2-3 minutes)"
  echo ""
  echo "💡 RECOMMENDED ACTION:"
  echo "   Run: ./fix-bastion-ssm.sh"
  exit 1
fi

PING_STATUS=$(echo "$SSM_INFO" | jq -r '.PingStatus')
LAST_PING=$(echo "$SSM_INFO" | jq -r '.LastPingDateTime')
PLATFORM=$(echo "$SSM_INFO" | jq -r '.PlatformType')
AGENT_VERSION=$(echo "$SSM_INFO" | jq -r '.AgentVersion')

echo "Ping Status:    $PING_STATUS"
echo "Last Ping:      $LAST_PING"
echo "Platform:       $PLATFORM"
echo "Agent Version:  $AGENT_VERSION"
echo ""

if [[ "$PING_STATUS" != "Online" ]]; then
  echo "⚠️  WARNING: SSM agent is not online!"
  echo "   Status: $PING_STATUS"
  echo ""
  echo "💡 RECOMMENDED ACTION:"
  echo "   Run: ./fix-bastion-ssm.sh"
  exit 1
fi

echo "✅ SSM agent is ONLINE and ready!"
echo ""

# Check 5: VPC Endpoint (if no public IP)
if [[ "$PUBLIC_IP" == "None" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🌐 CHECK 5: VPC Endpoints (no public IP detected)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  VPC_ID=$(echo "$INSTANCE_INFO" | jq -r '.VpcId')
  
  echo "Checking for SSM VPC endpoints in VPC: $VPC_ID"
  aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$VPC_ID" \
              "Name=service-name,Values=com.amazonaws.$REGION.ssm" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query "VpcEndpoints[].[ServiceName,State]" \
    --output table 2>/dev/null || echo "No SSM VPC endpoint found"
  
  echo ""
  echo "⚠️  Without public IP, you need VPC endpoints for SSM"
  echo ""
fi

# Check 6: System Log (last 30 lines)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 CHECK 6: System Log (last 30 lines)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Looking for SSM agent messages..."
echo ""
aws ec2 get-console-output \
  --instance-id "$INSTANCE_ID" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output text 2>/dev/null | grep -i "ssm\|systemd" | tail -30 || echo "No SSM-related messages found"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DIAGNOSTIC COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$PING_STATUS" == "Online" ]]; then
  echo ""
  echo "🎉 Everything looks good! You should be able to connect now:"
  echo ""
  echo "   ./connect-to-database.sh"
  echo ""
else
  echo ""
  echo "❌ Issues found. Run the fix script:"
  echo ""
  echo "   ./fix-bastion-ssm.sh"
  echo ""
fi

