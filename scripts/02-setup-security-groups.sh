#!/bin/bash

# Setup Security Groups

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/aws-helpers.sh"

set -a
source "$SCRIPT_DIR/.env"
set +a

STATE_FILE="$SCRIPT_DIR/state.json"
VPC_ID=$(jq -r '.vpc_id' "$STATE_FILE")

log_section "Creating Security Groups"

# ALB Security Group
log_info "Creating ALB Security Group..."
ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name "${PROJECT_NAME}-alb-sg" \
    --description "Security group for Application Load Balancer" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-alb-sg},{Key=Project,Value=$PROJECT_TAG}]" \
    --query 'GroupId' \
    --output text)

# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS from anywhere (if SSL configured)
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 || true

log_success "ALB Security Group created: $ALB_SG_ID"

# EC2 Security Group
log_info "Creating EC2 Security Group..."
EC2_SG_ID=$(aws ec2 create-security-group \
    --group-name "${PROJECT_NAME}-ec2-sg" \
    --description "Security group for EC2 instances" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-ec2-sg},{Key=Project,Value=$PROJECT_TAG}]" \
    --query 'GroupId' \
    --output text)

# Allow SSH
aws ec2 authorize-security-group-ingress \
    --group-id "$EC2_SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$SSH_ALLOWED_CIDR"

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress \
    --group-id "$EC2_SG_ID" \
    --protocol tcp \
    --port "$FRONTEND_PORT" \
    --source-group "$ALB_SG_ID"

aws ec2 authorize-security-group-ingress \
    --group-id "$EC2_SG_ID" \
    --protocol tcp \
    --port "$BACKEND_PORT" \
    --source-group "$ALB_SG_ID"

aws ec2 authorize-security-group-ingress \
    --group-id "$EC2_SG_ID" \
    --protocol tcp \
    --port "$BOTPRESS_PORT" \
    --source-group "$ALB_SG_ID"

log_success "EC2 Security Group created: $EC2_SG_ID"

# RDS Security Group
log_info "Creating RDS Security Group..."
RDS_SG_ID=$(aws ec2 create-security-group \
    --group-name "${PROJECT_NAME}-rds-sg" \
    --description "Security group for RDS database" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-rds-sg},{Key=Project,Value=$PROJECT_TAG}]" \
    --query 'GroupId' \
    --output text)

# Allow MySQL from EC2
aws ec2 authorize-security-group-ingress \
    --group-id "$RDS_SG_ID" \
    --protocol tcp \
    --port "$DB_PORT" \
    --source-group "$EC2_SG_ID"

log_success "RDS Security Group created: $RDS_SG_ID"

# Save to state
jq --arg alb "$ALB_SG_ID" --arg ec2 "$EC2_SG_ID" --arg rds "$RDS_SG_ID" \
   '.alb_sg_id = $alb | .ec2_sg_id = $ec2 | .rds_sg_id = $rds' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_success "Security groups created successfully"
