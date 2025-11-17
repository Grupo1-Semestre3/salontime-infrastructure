#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/ssh-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

BACKEND_IP=$(jq -r '.backend_public_ip' "$STATE_FILE")
DB_ENDPOINT=$(jq -r '.db_endpoint' "$STATE_FILE")

log_section "Deploying Backend Application"

log_info "Preparing deployment files..."
TMP_DIR="/tmp/backend-deploy-$$"
mkdir -p "$TMP_DIR"

cp -r "$SCRIPT_DIR/docker/backend/"* "$TMP_DIR/"

# Create application.properties
cat > "$TMP_DIR/application.properties" << ENVEOF
spring.datasource.url=jdbc:mysql://${DB_ENDPOINT}:${DB_PORT}/${DB_NAME}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
spring.jpa.hibernate.ddl-auto=update
server.port=${BACKEND_PORT}
ENVEOF

sed -i "s|BACKEND_REPO|$BACKEND_REPO|g" "$TMP_DIR/docker-compose.yml" || true
sed -i "s|BACKEND_BRANCH|$BACKEND_BRANCH|g" "$TMP_DIR/docker-compose.yml" || true
sed -i "s|BACKEND_PORT|$BACKEND_PORT|g" "$TMP_DIR/docker-compose.yml" || true

log_info "Copying files to backend instance..."
scp_to_remote "$TMP_DIR/Dockerfile" "$BACKEND_IP" "/home/ec2-user/Dockerfile" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/docker-compose.yml" "$BACKEND_IP" "/home/ec2-user/docker-compose.yml" "$KEY_FILE_PATH"
scp_to_remote "$TMP_DIR/application.properties" "$BACKEND_IP" "/home/ec2-user/application.properties" "$KEY_FILE_PATH"

log_info "Deploying backend container..."
ssh_exec "$BACKEND_IP" "$KEY_FILE_PATH" "
    cd /home/ec2-user && \
    docker-compose down 2>/dev/null || true && \
    docker-compose up -d --build
"

log_info "Waiting for backend to be healthy..."
sleep 45

check_container_health_remote "$BACKEND_IP" "$KEY_FILE_PATH" "backend" || log_warning "Backend health check failed"

rm -rf "$TMP_DIR"
log_success "Backend deployed successfully"
