#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/ssh-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

print_header "Updating Backend Application"

BACKEND_IP=$(jq -r '.backend_public_ip' "$STATE_FILE")

log_info "Creating backup of current image..."
ssh_exec "$BACKEND_IP" "$KEY_FILE_PATH" "
    docker tag backend:latest backend:backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
"

log_info "Pulling latest code and rebuilding..."
ssh_exec "$BACKEND_IP" "$KEY_FILE_PATH" "
    cd /home/ec2-user && \
    docker-compose pull && \
    docker-compose up -d --build --force-recreate
"

log_info "Waiting for backend to be healthy..."
sleep 45

if check_container_health_remote "$BACKEND_IP" "$KEY_FILE_PATH" "backend"; then
    log_success "Backend updated successfully"
else
    log_error "Backend update failed. Consider rolling back."
    exit 1
fi
