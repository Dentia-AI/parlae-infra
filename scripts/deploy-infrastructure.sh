#!/usr/bin/env bash
#
# Deploy both infrastructures
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/config.sh"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }

print_header() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
}

print_header "Deploying Infrastructure"

# Deploy dentia infrastructure
if [[ "${DEPLOY_FRONTEND}" == "true" || "${DEPLOY_BACKEND}" == "true" ]]; then
  print_header "[1/2] Main App Infrastructure"
  "${SCRIPT_DIR}/deploy-dentia-infrastructure.sh"
else
  log_info "Skipping main app infrastructure"
fi

# Deploy dentiahub infrastructure
if [[ "${DEPLOY_DISCOURSE}" == "true" ]]; then
  print_header "[2/2] Forum Infrastructure"
  "${SCRIPT_DIR}/deploy-dentiahub-infrastructure.sh"
else
  log_info "Skipping forum infrastructure"
fi

log_success "Infrastructure deployment complete!"

