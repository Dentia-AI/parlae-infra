#!/bin/bash

# AWS Resource Audit Script
# Checks for resources in both us-east-1 and us-east-2
# Looks for both "dentia" and "parlae" named resources

set -e

echo "==================================================================="
echo "AWS Resource Audit - Dentia/Parlae Infrastructure"
echo "==================================================================="
echo "Date: $(date)"
echo "AWS Profile: ${AWS_PROFILE:-default}"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "🔍 Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured or invalid."
    echo "Run: aws configure"
    exit 1
fi

echo "✅ AWS credentials verified"
echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "User/Role: $(aws sts get-caller-identity --query Arn --output text)"
echo ""

# Function to check resources in a region
audit_region() {
    local region=$1
    echo "==========================================="
    echo "Region: $region"
    echo "==========================================="
    
    echo ""
    echo "📦 ECS Clusters:"
    local clusters=$(aws ecs list-clusters --region $region --query 'clusterArns[]' --output text 2>/dev/null)
    if [ -z "$clusters" ]; then
        echo "  None found"
    else
        echo "$clusters" | grep -E "dentia|parlae" || echo "  None matching dentia/parlae"
    fi
    
    echo ""
    echo "⚖️  Load Balancers:"
    aws elbv2 describe-load-balancers --region $region --query 'LoadBalancers[].[LoadBalancerName,State.Code,DNSName]' --output table 2>/dev/null | grep -E "dentia|parlae|Name" || echo "  None matching dentia/parlae"
    
    echo ""
    echo "🗄️  RDS/Aurora Clusters:"
    aws rds describe-db-clusters --region $region --query 'DBClusters[].[DBClusterIdentifier,Status,Engine,DatabaseName]' --output table 2>/dev/null | grep -E "dentia|parlae|Identifier" || echo "  None matching dentia/parlae"
    
    echo ""
    echo "🎯 ECS Services:"
    local clusters_list=$(aws ecs list-clusters --region $region --query 'clusterArns[]' --output text 2>/dev/null)
    if [ -n "$clusters_list" ]; then
        for cluster in $clusters_list; do
            cluster_name=$(echo $cluster | awk -F'/' '{print $NF}')
            if echo "$cluster_name" | grep -qE "dentia|parlae"; then
                echo "  Cluster: $cluster_name"
                aws ecs list-services --cluster $cluster_name --region $region --query 'serviceArns[]' --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) print "    - " $i}'
            fi
        done
    else
        echo "  No ECS clusters found"
    fi
    
    echo ""
    echo "🐳 ECR Repositories:"
    aws ecr describe-repositories --region $region --query 'repositories[].[repositoryName,repositoryUri]' --output table 2>/dev/null | grep -E "dentia|parlae|Name" || echo "  None matching dentia/parlae"
    
    echo ""
    echo "🔐 ACM Certificates:"
    aws acm list-certificates --region $region --query 'CertificateSummaryList[].[DomainName,Status]' --output table 2>/dev/null | grep -E "dentia|parlae|Domain|parlae.ca" || echo "  None matching dentia/parlae"
    
    echo ""
    echo "📊 CloudWatch Log Groups:"
    aws logs describe-log-groups --region $region --query 'logGroups[].logGroupName' --output text 2>/dev/null | grep -E "dentia|parlae" | head -10 || echo "  None matching dentia/parlae"
    
    echo ""
    echo "👥 IAM Roles (checking for dentia/parlae prefix):"
    aws iam list-roles --query 'Roles[].RoleName' --output text 2>/dev/null | tr '\t' '\n' | grep -E "dentia|parlae" | head -10 || echo "  None matching dentia/parlae"
    
    echo ""
}

# Check S3 buckets (global)
echo "🪣 S3 Buckets (Global):"
aws s3 ls 2>/dev/null | grep -E "dentia|parlae" || echo "  None matching dentia/parlae"
echo ""

# Audit both regions
audit_region "us-east-2"
echo ""
audit_region "us-east-1"

echo ""
echo "==================================================================="
echo "Audit Complete"
echo "==================================================================="
echo ""
echo "📝 Summary:"
echo "  - Check for duplicate resources (both dentia and parlae)"
echo "  - us-east-2 should have your main infrastructure"
echo "  - us-east-1 should ONLY have CloudFront ACM certificate (if prod)"
echo ""
echo "💡 Next Steps:"
echo "  1. If you see duplicate 'dentia' resources, plan migration or cleanup"
echo "  2. Verify no unexpected resources in us-east-1"
echo "  3. Consider cleaning up old resources to reduce costs"
echo ""
echo "💰 Cost Impact of Duplicates:"
echo "  - ALB: ~\$16-25/month each"
echo "  - Aurora: ~\$0.12/hour per ACU (can be hundreds/month)"
echo "  - NAT Gateway: ~\$32/month each"
echo ""
echo "📖 See AWS_RESOURCES_AUDIT.md for detailed information"
echo ""
