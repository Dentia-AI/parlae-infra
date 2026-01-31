#!/usr/bin/env bash
#
# Deploy dentia infrastructure
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

cd "${ROOT_DIR}/dentia-infra"

log_info "Initializing Terraform..."
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${PROJECT_NAME}/dentia-infra/terraform.tfstate" \
  -backend-config="region=${TF_STATE_REGION}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
  -backend-config="profile=${AWS_PROFILE}"

log_info "Planning infrastructure changes..."
terraform plan \
  -var="project_name=${PROJECT_NAME}" \
  -var="region=${AWS_REGION}" \
  -var="domain=${APEX_DOMAIN}" \
  -var="app_domain=${APP_DOMAIN}" \
  -var="api_domain=${API_DOMAIN}" \
  -var="db_master_username=${DB_MASTER_USERNAME:-admin}" \
  -var="db_master_password=${DB_MASTER_PASSWORD}" \
  -var="db_name=${DB_NAME}" \
  -var="environment=${ENVIRONMENT}" \
  -out=tfplan

log_info "Applying infrastructure changes..."
terraform apply tfplan

log_success "Main app infrastructure deployed!"

# Save outputs
terraform output -json > "${ROOT_DIR}/.outputs/dentia-infra.json"

