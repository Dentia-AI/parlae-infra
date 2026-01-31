# Bastion Fix - Quick Start Guide

## ✅ What Was Fixed

Your bastion instance was using `t3.nano` (0.5 GB RAM) which was **way too small** and kept crashing. This caused the instance ID to keep changing and the "TargetNotConnected" errors you were seeing.

## 🚀 Upgrades Applied

| Feature | Before (t3.nano) | After (t3.small) |
|---------|------------------|------------------|
| **RAM** | 0.5 GB | 2 GB ✅ |
| **Stability** | Crashes frequently ❌ | Stable ✅ |
| **Auto-Recovery** | None | CloudWatch alarm ✅ |
| **Monitoring** | Basic | Detailed ✅ |
| **SSM Agent** | Manual | Auto-updates ✅ |
| **Storage** | 8 GB | 20 GB GP3 ✅ |
| **Cost** | ~$4/month | ~$15/month |

---

## 📋 How to Deploy (2 Steps)

### Step 1: Apply Terraform Changes

```bash
cd ~/Projects/Dentia/dentia-infra/infra/ecs
terraform apply
```

This will:
- Create a new `t3.small` bastion instance
- Add auto-recovery CloudWatch alarm
- Configure monitoring and user data
- Terminate the old `t3.nano` instance

### Step 2: Test the New Bastion

Use the new helper script that automatically finds your bastion:

```bash
cd ~/Projects/Dentia/dentia-infra
./connect-to-database.sh
```

That's it! The script will:
- 🔍 Find the running bastion instance
- ✅ Verify it's connected to SSM
- 🚀 Start the port forwarding tunnel
- 📋 Show you how to connect

---

## 🎯 Quick Connect Command

**New way (Easy):**
```bash
cd ~/Projects/Dentia/dentia-infra
./connect-to-database.sh
```

**Old way (Manual):**
```bash
# 1. Find instance ID manually
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dentia-bastion" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --profile dentia \
  --region us-east-2)

# 2. Start tunnel with that ID
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["dentia-aurora-cluster.cluster-c9kuy2skoi93.us-east-2.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["15432"]}' \
  --profile dentia \
  --region us-east-2
```

---

## ✨ Benefits

### Before
- ❌ Bastion crashed frequently
- ❌ Instance ID kept changing  
- ❌ Had to manually find new instance ID each time
- ❌ "TargetNotConnected" errors
- ❌ No way to recover automatically

### After
- ✅ Stable and reliable
- ✅ **Instance ID stays the same**
- ✅ Helper script automatically finds it
- ✅ Auto-recovers on failures
- ✅ Detailed monitoring

---

## 📖 Documentation

- **Quick Start**: This file
- **Complete Guide**: `BASTION_IMPROVEMENTS.md` (troubleshooting, monitoring, costs)
- **Helper Script**: `connect-to-database.sh` (automatic connection)

---

## 🆘 Troubleshooting

### Still getting "TargetNotConnected"?

**Wait 2-3 minutes** after applying terraform for the SSM agent to register.

**Then verify:**
```bash
aws ssm describe-instance-information \
  --filters "Key=tag:Name,Values=dentia-bastion" \
  --profile dentia \
  --region us-east-2
```

Should show `PingStatus: Online`

### Need more help?

See `BASTION_IMPROVEMENTS.md` for complete troubleshooting guide.

---

## 💡 Pro Tip

Bookmark this command:
```bash
alias connect-db='cd ~/Projects/Dentia/dentia-infra && ./connect-to-database.sh'
```

Then just run: `connect-db` 🚀

