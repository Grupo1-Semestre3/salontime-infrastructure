#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/ssh-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

FRONTEND_IP=$(jq -r '.frontend_public_ip' "$STATE_FILE")
DB_ENDPOINT=$(jq -r '.db_endpoint' "$STATE_FILE")

log_section "Deploying Frontend Application"

log_info "Preparing deployment files..."
TMP_DIR="/tmp/frontend-deploy-$$"
mkdir -p "$TMP_DIR"

# Copy Dockerfile and docker-compose
cp -r "$SCRIPT_DIR/docker/frontend/"* "$TMP_DIR/"

# Create .env for frontend
cat > "$TMP_DIR/.env" << ENVEOF
VITE_API_URL=http://localhost:${BACKEND_PORT}
VITE_BOT_URL=http://localhost:${BOTPRESS_PORT}
ENVEOF

# Update docker-compose.yml with repository
sed -i "s|FRONTEND_REPO|$FRONTEND_REPO|g" "$TMP_DIR/docker-compose.yml" || true
sed -i "s|FRONTEND_BRANCH|$FRONTEND_BRANCH|g" "$TMP_DIR/docker-compose.yml" || true
sed -i "s|FRONTEND_PORT|$FRONTEND_PORT|g" "$TMP_DIR/docker-compose.yml" || true

log_info "Copying files to frontend instance..."
scp_to_remote "$TMP_DIR/Dockerfile" "$FRONTEND_IP" "/home/ec2-user/Dockerfile" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/docker-compose.yml" "$FRONTEND_IP" "/home/ec2-user/docker-compose.yml" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/.env" "$FRONTEND_IP" "/home/ec2-user/.env" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/nginx.conf" "$FRONTEND_IP" "/home/ec2-user/nginx.conf" "$KEY_FILE_PATH" || true

log_info "Deploying frontend container..."
ssh_exec "$FRONTEND_IP" "$KEY_FILE_PATH" "
    cd /home/ec2-user && \
    docker-compose down 2>/dev/null || true && \
    docker-compose up -d --build
"

log_info "Waiting for frontend to be healthy..."
sleep 30

check_container_health_remote "$FRONTEND_IP" "$KEY_FILE_PATH" "frontend" || log_warning "Frontend health check failed"

rm -rf "$TMP_DIR"
log_success "Frontend deployed successfully"
