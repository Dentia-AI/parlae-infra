# Old VPC Cleanup

## Background

During Terraform state reconciliation (Feb 2026), two VPCs named `parlae-vpc` were discovered in `us-east-2`:

| VPC ID | Status | Notes |
|--------|--------|-------|
| `vpc-072ff6c4af9465030` | **ACTIVE** | Used by ALB, Aurora, ECS services, bastion |
| `vpc-08d61687c19876eb1` | **OLD / UNUSED** | Empty — no active resources attached |

The active VPC is correctly tracked in Terraform state. The old VPC is not managed by Terraform and appears to have no resources.

## Recommended Action

After confirming the old VPC has no remaining resources (ENIs, NAT gateways, subnets with active instances, etc.), it can be safely deleted via the AWS Console:

1. Go to **VPC Console** → **Your VPCs**
2. Select `vpc-08d61687c19876eb1`
3. Verify **0 running instances**, **0 NAT gateways**, **0 endpoints**
4. Choose **Actions** → **Delete VPC**
5. AWS will cascade-delete associated subnets, route tables, and security groups

## Verification Commands

```bash
# Check for any resources in the old VPC
aws ec2 describe-instances --filters 'Name=vpc-id,Values=vpc-08d61687c19876eb1' --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table --region us-east-2 --profile parlae

aws ec2 describe-network-interfaces --filters 'Name=vpc-id,Values=vpc-08d61687c19876eb1' --query 'NetworkInterfaces[*].[NetworkInterfaceId,Description]' --output table --region us-east-2 --profile parlae

aws ec2 describe-nat-gateways --filter 'Name=vpc-id,Values=vpc-08d61687c19876eb1' --query 'NatGateways[*].[NatGatewayId,State]' --output table --region us-east-2 --profile parlae
```

## Risk

**Low.** The old VPC has no associated active resources. Deleting it removes a source of confusion (two VPCs with the same name).
