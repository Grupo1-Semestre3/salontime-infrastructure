#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/ssh-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

BOTPRESS_IP=$(jq -r '.botpress_public_ip' "$STATE_FILE")

log_section "Deploying BotPress Chatbot"

log_info "Preparing deployment files..."
TMP_DIR="/tmp/botpress-deploy-$$"
mkdir -p "$TMP_DIR"

cp -r "$SCRIPT_DIR/docker/botpress/"* "$TMP_DIR/"

sed -i "s|BOTPRESS_REPO|$BOTPRESS_REPO|g" "$TMP_DIR/docker-compose.yml" || true
sed -i "s|BOTPRESS_BRANCH|$BOTPRESS_BRANCH|g" "$TMP_DIR/docker-compose.yml" || true
sed -i "s|BOTPRESS_PORT|$BOTPRESS_PORT|g" "$TMP_DIR/docker-compose.yml" || true

log_info "Copying files to botpress instance..."
scp_to_remote "$TMP_DIR/Dockerfile" "$BOTPRESS_IP" "/home/ec2-user/Dockerfile" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/docker-compose.yml" "$BOTPRESS_IP" "/home/ec2-user/docker-compose.yml" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/botpress.config.json" "$BOTPRESS_IP" "/home/ec2-user/botpress.config.json" "$KEY_FILE_PATH" || true

log_info "Deploying botpress container..."
ssh_exec "$BOTPRESS_IP" "$KEY_FILE_PATH" "
    cd /home/ec2-user && \
    docker-compose down 2>/dev/null || true && \
    docker-compose up -d --build
"

log_info "Waiting for botpress to be healthy..."
sleep 30

check_container_health_remote "$BOTPRESS_IP" "$KEY_FILE_PATH" "botpress" || log_warning "BotPress health check failed"

rm -rf "$TMP_DIR"
log_success "BotPress deployed successfully"
