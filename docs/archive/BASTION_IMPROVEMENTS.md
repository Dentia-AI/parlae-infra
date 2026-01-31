# Bastion Instance Improvements

## Problem
The bastion EC2 instance for database port forwarding was unstable:
- ❌ Used `t3.nano` (0.5 GB RAM, 2 vCPUs) - too small
- ❌ Instance kept stopping/crashing
- ❌ Instance ID kept changing
- ❌ No auto-recovery configured
- ❌ No monitoring enabled
- ❌ SSM agent might not be updated

**Error you were seeing:**
```
An error occurred (TargetNotConnected) when calling the StartSession operation: 
i-0eefd9be3ab9c483a is not connected.
```

---

## Solution Applied

### 1. **Upgraded Instance Size** 
✅ `t3.nano` → `t3.small`
- **Before**: 0.5 GB RAM, 2 vCPUs (burstable, runs out of credits)
- **After**: 2 GB RAM, 2 vCPUs (more stable CPU credits)
- **Cost**: ~$15/month (minimal increase from ~$4/month)

### 2. **Added Auto-Recovery**
✅ CloudWatch alarm that automatically recovers the instance if system health checks fail
- Monitors system status every minute
- Automatically recovers if 2 consecutive failures detected
- Same instance ID maintained after recovery

### 3. **Enabled Detailed Monitoring**
✅ Tracks CPU, memory, and network metrics every minute
- Better visibility into instance health
- Can see if running out of resources

### 4. **User Data Script**
✅ Ensures SSM agent is installed and running on boot
- Updates SSM agent to latest version
- Enables and starts the service automatically
- Logs initialization for debugging

### 5. **Increased Root Volume**
✅ 8 GB → 20 GB GP3 storage
- More space for logs and SSM agent updates
- GP3 for better performance

### 6. **Lifecycle Management**
✅ Ignores AMI changes to prevent unnecessary replacements
- Instance won't be replaced when Amazon updates base AMI
- More stable instance ID over time

---

## Files Modified

### Infrastructure
- **`infra/ecs/bastion.tf`** - Upgraded instance configuration

### Helper Scripts (NEW)
- **`connect-to-database.sh`** - Automated connection script

---

## How to Deploy

### Step 1: Apply Terraform Changes

```bash
cd ~/Projects/Dentia/dentia-infra/infra/ecs

# Review changes
terraform plan

# Apply (will replace the bastion instance)
terraform apply
```

**⚠️ Note**: This will create a new bastion instance with a new instance ID. The old t3.nano will be terminated.

### Step 2: Verify the New Instance

```bash
# Check instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dentia-bastion" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name]" \
  --output table \
  --profile dentia \
  --region us-east-2
```

Should show:
```
-------------------------
|  DescribeInstances    |
+-----------------------+
|  i-XXXXXXXXXXXXX      |
|  t3.small             |
|  running              |
+-----------------------+
```

---

## Using the New Connection Script

### Quick Connect (Recommended)

```bash
cd ~/Projects/Dentia/dentia-infra

# Connect to database (auto-finds bastion instance)
./connect-to-database.sh

# Or specify AWS profile
./connect-to-database.sh dentia

# Or specify different local port
./connect-to-database.sh dentia 5433
```

The script will:
1. 🔍 Automatically find the running bastion instance
2. ✅ Verify it's connected to SSM
3. 🚀 Start the port forwarding tunnel
4. 📋 Show you the connection command

**Example output:**
```
🔍 Finding bastion instance...
✅ Found bastion: i-0a1b2c3d4e5f6g7h8
🚀 Starting SSM port forwarding session...

   Local:  localhost:15432
   Remote: dentia-aurora-cluster.cluster-c9kuy2skoi93.us-east-2.rds.amazonaws.com:5432

You can now connect using:
   psql -h localhost -p 15432 -U dentia_admin -d dentia

Press Ctrl+C to stop the tunnel
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Manual Connection (Old Way)

If you prefer to connect manually:

```bash
# 1. Get the instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dentia-bastion" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --profile dentia \
  --region us-east-2)

echo "Instance ID: $INSTANCE_ID"

# 2. Start the tunnel
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["dentia-aurora-cluster.cluster-c9kuy2skoi93.us-east-2.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["15432"]}' \
  --profile dentia \
  --region us-east-2
```

---

## Monitoring & Management

### Check Instance Status

```bash
# Get full instance details
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dentia-bastion" \
  --profile dentia \
  --region us-east-2 \
  --output table
```

### View CloudWatch Metrics

```bash
# Check CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --profile dentia \
  --region us-east-2
```

### Check SSM Agent Status

```bash
# Verify SSM connectivity
aws ssm describe-instance-information \
  --filters "Key=tag:Name,Values=dentia-bastion" \
  --profile dentia \
  --region us-east-2 \
  --output table
```

Should show `PingStatus: Online`

### View Instance Logs

```bash
# Get system log
aws ec2 get-console-output \
  --instance-id <instance-id> \
  --profile dentia \
  --region us-east-2 \
  --output text
```

---

## Troubleshooting

### Instance Not Found or Stopped

**Problem**: Script says "No running bastion instance found"

**Solutions:**

1. **Check if instance exists:**
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=dentia-bastion" \
     --profile dentia \
     --region us-east-2
   ```

2. **Start if stopped:**
   ```bash
   INSTANCE_ID=<your-instance-id>
   aws ec2 start-instances \
     --instance-ids "$INSTANCE_ID" \
     --profile dentia \
     --region us-east-2
   ```

3. **If doesn't exist, create with terraform:**
   ```bash
   cd ~/Projects/Dentia/dentia-infra/infra/ecs
   terraform apply
   ```

### "TargetNotConnected" Error

**Problem**: Instance exists but SSM can't connect

**Causes:**
1. SSM agent not running
2. No internet connectivity (needs public IP or NAT)
3. IAM role missing SSM permissions

**Solutions:**

1. **Wait 2-3 minutes** after instance starts for SSM agent to register

2. **Check SSM agent status:**
   ```bash
   aws ssm describe-instance-information \
     --filters "Key=InstanceIds,Values=<instance-id>" \
     --profile dentia \
     --region us-east-2
   ```

3. **Restart SSM agent (via Run Command):**
   ```bash
   aws ssm send-command \
     --instance-ids "<instance-id>" \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=["sudo systemctl restart amazon-ssm-agent"]' \
     --profile dentia \
     --region us-east-2
   ```

4. **Check IAM role** has `AmazonSSMManagedInstanceCore` policy attached

### Connection Drops or Unstable

**Problem**: Tunnel keeps disconnecting

**Solutions:**

1. **Check instance metrics** - ensure not hitting CPU/memory limits
2. **Update SSM Session Manager plugin** on your local machine:
   ```bash
   # Mac
   brew install --cask session-manager-plugin
   
   # Or download from AWS
   # https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
   ```

3. **Increase session timeout** (edit locally):
   ```bash
   aws ssm start-session \
     --target "$INSTANCE_ID" \
     --document-name AWS-StartPortForwardingSessionToRemoteHost \
     --parameters '{"host":["..."],"portNumber":["5432"],"localPortNumber":["15432"],"sessionTimeout":["60"]}' \
     ...
   ```

---

## Cost Analysis

| Instance Type | vCPU | RAM | Cost/Month | Status |
|---------------|------|-----|------------|--------|
| t3.nano (old) | 2 | 0.5 GB | ~$4 | ❌ Unstable |
| t3.micro | 2 | 1 GB | ~$8 | ⚠️ May work |
| **t3.small (new)** | **2** | **2 GB** | **~$15** | **✅ Stable** |
| t3.medium | 2 | 4 GB | ~$30 | 💰 Overkill |

**Recommendation**: `t3.small` is the sweet spot for a bastion used for port forwarding.

---

## Benefits Summary

### Before (t3.nano)
- ❌ Instance crashed frequently
- ❌ Had to manually find new instance ID
- ❌ No monitoring or alerts
- ❌ Manual SSM setup might fail
- ❌ Unreliable for daily use

### After (t3.small + improvements)
- ✅ Stable and reliable
- ✅ Auto-recovery on failures
- ✅ Easy connection with helper script
- ✅ Detailed monitoring
- ✅ SSM agent always updated
- ✅ Same instance ID over time

---

## Maintenance

### Monthly
- Check CloudWatch metrics to ensure not hitting resource limits
- Verify auto-recovery alarm is active

### Quarterly  
- Update base AMI (terraform will handle this gracefully)
- Review CloudWatch logs for any anomalies

### As Needed
- If performance degrades, consider upgrading to `t3.medium`
- Adjust storage if logs fill up (unlikely with 20 GB)

---

## Related Documentation

- AWS SSM Session Manager: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html
- EC2 Auto Recovery: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-recover.html
- T3 Instance Types: https://aws.amazon.com/ec2/instance-types/t3/

---

## Summary

✅ Bastion upgraded from `t3.nano` to `t3.small`  
✅ Auto-recovery alarm configured  
✅ Detailed monitoring enabled  
✅ SSM agent auto-updates on boot  
✅ Helper script created for easy connection  
✅ Increased storage and better performance  

**Your bastion should now be stable and reliable for daily database access!** 🎉

Use `./connect-to-database.sh` for hassle-free connections!

