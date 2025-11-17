#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/ssh-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

print_header "Rolling Back Frontend Application"

FRONTEND_IP=$(jq -r '.frontend_public_ip' "$STATE_FILE")

log_info "Listing available backups..."
BACKUPS=$(ssh_exec "$FRONTEND_IP" "$KEY_FILE_PATH" "docker images | grep 'frontend.*backup' | awk '{print \$2}'")

if [ -z "$BACKUPS" ]; then
    log_error "No backup images found"
    exit 1
fi

echo "$BACKUPS"
read -p "Enter backup tag to restore (or press Enter for most recent): " BACKUP_TAG

if [ -z "$BACKUP_TAG" ]; then
    BACKUP_TAG=$(echo "$BACKUPS" | head -1)
fi

log_info "Rolling back to: frontend:$BACKUP_TAG"

ssh_exec "$FRONTEND_IP" "$KEY_FILE_PATH" "
    docker stop frontend 2>/dev/null || true && \
    docker rm frontend 2>/dev/null || true && \
    docker run -d --name frontend -p ${FRONTEND_PORT}:80 frontend:$BACKUP_TAG
"

log_success "Frontend rolled back to $BACKUP_TAG"
