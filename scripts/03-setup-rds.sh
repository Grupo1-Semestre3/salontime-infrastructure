#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/aws-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

log_section "Creating RDS Subnet Group"

PRIVATE_SUBNET1_ID=$(jq -r '.private_subnet1_id' "$STATE_FILE")
PRIVATE_SUBNET2_ID=$(jq -r '.private_subnet2_id' "$STATE_FILE")
RDS_SG_ID=$(jq -r '.rds_sg_id' "$STATE_FILE")

DB_SUBNET_GROUP="${PROJECT_NAME}-db-subnet-group"

aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subnet group for ${PROJECT_NAME} RDS" \
    --subnet-ids "$PRIVATE_SUBNET1_ID" "$PRIVATE_SUBNET2_ID" \
    --tags "Key=Name,Value=$DB_SUBNET_GROUP" "Key=Project,Value=$PROJECT_TAG" || log_warning "Subnet group may already exist"

log_success "RDS Subnet Group ready: $DB_SUBNET_GROUP"

log_section "Creating RDS MySQL Instance"

DB_IDENTIFIER="${PROJECT_NAME}-db"

aws rds create-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-instance-class "$DB_INSTANCE_CLASS" \
    --engine mysql \
    --engine-version "$DB_ENGINE_VERSION" \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage "$DB_ALLOCATED_STORAGE" \
    --db-name "$DB_NAME" \
    --vpc-security-group-ids "$RDS_SG_ID" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --backup-retention-period "$DB_BACKUP_RETENTION" \
    --port "$DB_PORT" \
    --multi-az --multi-az \
    --no-publicly-accessible \
    --tags "Key=Name,Value=$DB_IDENTIFIER" "Key=Project,Value=$PROJECT_TAG" || log_warning "RDS instance may already exist"

log_info "Waiting for RDS instance to be available (this may take 10-15 minutes)..."
wait_for_resource "rds-instance" "$DB_IDENTIFIER" 900

DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

log_success "RDS instance available: $DB_ENDPOINT"

jq --arg endpoint "$DB_ENDPOINT" --arg identifier "$DB_IDENTIFIER" \
   '.db_endpoint = $endpoint | .db_identifier = $identifier' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_section "Initializing Database Schema"

# Clone DB repo and execute SQL scripts
TMP_DIR="/tmp/salontime-db-$$"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

git clone "$DB_REPO" db-scripts || log_warning "Failed to clone DB repo"
cd db-scripts 2>/dev/null || cd "$TMP_DIR"

if [ -f "criacao_bd.sql" ]; then
    log_info "Executing database creation script..."
    # Note: Actual execution would require mysql client on a bastion or EC2
    log_warning "Database scripts need to be executed manually or via EC2 bastion"
fi

cd "$SCRIPT_DIR"
rm -rf "$TMP_DIR"

log_success "RDS setup complete"
