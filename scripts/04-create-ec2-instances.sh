#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/aws-helpers.sh"
source "$SCRIPT_DIR/utils/ssh-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

PUBLIC_SUBNET_ID=$(jq -r '.public_subnet_id' "$STATE_FILE")
EC2_SG_ID=$(jq -r '.ec2_sg_id' "$STATE_FILE")

if [ -z "$AMI_ID" ]; then
    AMI_ID=$(get_latest_ami "$AWS_REGION")
    log_info "Using latest Amazon Linux 2 AMI: $AMI_ID"
fi

create_instance() {
    local name=$1
    local instance_type=$2
    
    log_info "Creating EC2 instance: $name"
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$instance_type" \
        --key-name "$KEY_PAIR_NAME" \
        --security-group-ids "$EC2_SG_ID" \
        --subnet-id "$PUBLIC_SUBNET_ID" \
        --associate-public-ip-address \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-${name}},{Key=Project,Value=$PROJECT_TAG},{Key=Role,Value=$name}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    log_success "Instance created: $INSTANCE_ID"
    log_info "Waiting for instance to be running..."
    wait_for_resource "ec2-instance" "$INSTANCE_ID" 300
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    log_success "Instance $name ready: $PUBLIC_IP"
    
    # Wait for SSH and install Docker
    wait_for_ssh "$PUBLIC_IP" "$KEY_FILE_PATH" 300
    install_docker_remote "$PUBLIC_IP" "$KEY_FILE_PATH"
    install_docker_compose_remote "$PUBLIC_IP" "$KEY_FILE_PATH"
    
    echo "$INSTANCE_ID|$PUBLIC_IP"
}

log_section "Creating EC2 Instances"

# Frontend Instance
FRONTEND_INFO=$(create_instance "frontend" "$FRONTEND_INSTANCE_TYPE")
FRONTEND_INSTANCE_ID=$(echo "$FRONTEND_INFO" | cut -d'|' -f1)
FRONTEND_PUBLIC_IP=$(echo "$FRONTEND_INFO" | cut -d'|' -f2)

# Backend Instance
BACKEND_INFO=$(create_instance "backend" "$BACKEND_INSTANCE_TYPE")
BACKEND_INSTANCE_ID=$(echo "$BACKEND_INFO" | cut -d'|' -f1)
BACKEND_PUBLIC_IP=$(echo "$BACKEND_INFO" | cut -d'|' -f2)

# BotPress Instance
BOTPRESS_INFO=$(create_instance "botpress" "$BOTPRESS_INSTANCE_TYPE")
BOTPRESS_INSTANCE_ID=$(echo "$BOTPRESS_INFO" | cut -d'|' -f1)
BOTPRESS_PUBLIC_IP=$(echo "$BOTPRESS_INFO" | cut -d'|' -f2)

# Save to state
jq --arg fid "$FRONTEND_INSTANCE_ID" --arg fip "$FRONTEND_PUBLIC_IP" \
   --arg bid "$BACKEND_INSTANCE_ID" --arg bip "$BACKEND_PUBLIC_IP" \
   --arg pid "$BOTPRESS_INSTANCE_ID" --arg pip "$BOTPRESS_PUBLIC_IP" \
   '.frontend_instance_id = $fid | .frontend_public_ip = $fip | 
    .backend_instance_id = $bid | .backend_public_ip = $bip |
    .botpress_instance_id = $pid | .botpress_public_ip = $pip' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_success "All EC2 instances created and ready"
