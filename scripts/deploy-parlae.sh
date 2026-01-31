#!/usr/bin/env bash
#
# Deploy main app (dentia)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/config.sh"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }

cd "${ROOT_DIR}/dentia"

# Build and push to ECR
log_info "Building and pushing Docker images..."

# Get ECR registry
ACCOUNT_ID=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
aws ecr get-login-password --profile "${AWS_PROFILE}" --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# Build and push frontend
if [[ "${DEPLOY_FRONTEND}" == "true" ]]; then
  log_info "Building frontend for linux/amd64..."
  docker buildx build \
    --platform linux/amd64 \
    -t "${ECR_REGISTRY}/${PROJECT_NAME}-frontend:latest" \
    -f infra/docker/frontend.Dockerfile \
    --push \
    .
  log_success "Frontend pushed to ECR"
fi

# Build and push backend
if [[ "${DEPLOY_BACKEND}" == "true" ]]; then
  log_info "Building backend for linux/amd64..."
  docker buildx build \
    --platform linux/amd64 \
    -t "${ECR_REGISTRY}/${PROJECT_NAME}-backend:latest" \
    -f infra/docker/backend.Dockerfile \
    --push \
    .
  log_success "Backend pushed to ECR"
fi

# Force ECS deployment
log_info "Forcing ECS deployment..."
aws ecs update-service \
  --cluster "${PROJECT_NAME}-cluster" \
  --service "${PROJECT_NAME}-frontend" \
  --force-new-deployment \
  --profile "${AWS_PROFILE}" \
  --region "${AWS_REGION}" \
  --no-cli-pager 2>/dev/null || true

aws ecs update-service \
  --cluster "${PROJECT_NAME}-cluster" \
  --service "${PROJECT_NAME}-backend" \
  --force-new-deployment \
  --profile "${AWS_PROFILE}" \
  --region "${AWS_REGION}" \
  --no-cli-pager 2>/dev/null || true

log_success "Main app deployed!"

