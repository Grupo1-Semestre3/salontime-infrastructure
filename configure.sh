#!/bin/bash

# SalonTime Infrastructure Configuration Wizard
# Interactive setup for all environment variables

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/validators.sh"

# Initialize
ENV_FILE="$SCRIPT_DIR/.env"

print_header "SalonTime AWS Infrastructure Configuration Wizard"

print_info "This wizard will guide you through configuring the SalonTime infrastructure."
print_info "Press Ctrl+C at any time to cancel."
echo ""

# Check if .env already exists
if [ -f "$ENV_FILE" ]; then
    print_warning ".env file already exists."
    read -p "Do you want to overwrite it? (y/n): " overwrite
    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
        print_info "Configuration cancelled."
        exit 0
    fi
fi

# Function to prompt for input with validation
prompt_input() {
    local var_name=$1
    local prompt_text=$2
    local default_value=$3
    local validator=$4
    local value=""
    
    while true; do
        if [ -n "$default_value" ]; then
            read -p "$prompt_text [$default_value]: " value
            value=${value:-$default_value}
        else
            read -p "$prompt_text: " value
        fi
        
        # If validator provided, validate
        if [ -n "$validator" ]; then
            if $validator "$value"; then
                break
            else
                print_error "Invalid input. Please try again."
            fi
        else
            if [ -n "$value" ]; then
                break
            else
                print_error "This field cannot be empty."
            fi
        fi
    done
    
    echo "$value"
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt_text=$1
    local default_value=${2:-y}
    
    while true; do
        read -p "$prompt_text (y/n) [$default_value]: " answer
        answer=${answer:-$default_value}
        
        case ${answer,,} in
            y|yes) echo "true"; return 0 ;;
            n|no) echo "false"; return 0 ;;
            *) print_error "Please answer y or n." ;;
        esac
    done
}

# Start configuration
print_section "AWS Configuration"

AWS_REGION=$(prompt_input "AWS_REGION" "AWS Region" "us-east-1" "validate_aws_region")
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_warning "Could not auto-detect AWS Account ID. Please enter it manually."
    AWS_ACCOUNT_ID=$(prompt_input "AWS_ACCOUNT_ID" "AWS Account ID" "" "")
fi
print_success "AWS Account ID: $AWS_ACCOUNT_ID"

print_section "Project Configuration"

PROJECT_NAME=$(prompt_input "PROJECT_NAME" "Project Name" "salontime" "validate_resource_name")
ENVIRONMENT=$(prompt_input "ENVIRONMENT" "Environment (dev/staging/production)" "production" "validate_environment")

print_section "Network Configuration"

VPC_CIDR=$(prompt_input "VPC_CIDR" "VPC CIDR Block" "10.0.0.0/16" "validate_cidr")
PUBLIC_SUBNET_CIDR=$(prompt_input "PUBLIC_SUBNET_CIDR" "Public Subnet CIDR" "10.0.1.0/24" "validate_cidr")
PRIVATE_SUBNET1_CIDR=$(prompt_input "PRIVATE_SUBNET1_CIDR" "Private Subnet 1 CIDR" "10.0.2.0/24" "validate_cidr")
PRIVATE_SUBNET2_CIDR=$(prompt_input "PRIVATE_SUBNET2_CIDR" "Private Subnet 2 CIDR" "10.0.3.0/24" "validate_cidr")

AZ1=$(prompt_input "AZ1" "Availability Zone 1" "${AWS_REGION}a" "")
AZ2=$(prompt_input "AZ2" "Availability Zone 2" "${AWS_REGION}b" "")

print_section "EC2 Configuration"

print_info "Instance types (t3.small for dev, t3.medium for production):"
FRONTEND_INSTANCE_TYPE=$(prompt_input "FRONTEND_INSTANCE_TYPE" "Frontend Instance Type" "t3.medium" "validate_instance_type")
BACKEND_INSTANCE_TYPE=$(prompt_input "BACKEND_INSTANCE_TYPE" "Backend Instance Type" "t3.medium" "validate_instance_type")
BOTPRESS_INSTANCE_TYPE=$(prompt_input "BOTPRESS_INSTANCE_TYPE" "BotPress Instance Type" "t3.medium" "validate_instance_type")

KEY_PAIR_NAME=$(prompt_input "KEY_PAIR_NAME" "SSH Key Pair Name (must exist in AWS)" "" "")
KEY_FILE_PATH=$(prompt_input "KEY_FILE_PATH" "Path to SSH Private Key (.pem)" "" "")

print_section "RDS Database Configuration"

DB_INSTANCE_CLASS=$(prompt_input "DB_INSTANCE_CLASS" "RDS Instance Class" "db.t3.medium" "validate_rds_instance_class")
DB_NAME=$(prompt_input "DB_NAME" "Database Name" "salontime_db" "")
DB_USERNAME=$(prompt_input "DB_USERNAME" "Database Username" "admin" "")

while true; do
    read -s -p "Database Password (min 8 chars, letters+numbers): " DB_PASSWORD
    echo ""
    if validate_password "$DB_PASSWORD" 8; then
        read -s -p "Confirm Password: " DB_PASSWORD_CONFIRM
        echo ""
        if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
            break
        else
            print_error "Passwords do not match. Please try again."
        fi
    fi
done

DB_MULTI_AZ=$(prompt_yes_no "Enable Multi-AZ for RDS (recommended for production)" "y")

print_section "Application Repositories"

print_info "Default repositories will be used. Press Enter to accept or provide custom URLs."
FRONTEND_REPO=$(prompt_input "FRONTEND_REPO" "Frontend Repository" "https://github.com/Grupo1-Semestre3/salontime-front-end-react" "")
BACKEND_REPO=$(prompt_input "BACKEND_REPO" "Backend Repository" "https://github.com/Grupo1-Semestre3/salontime-app-kotlin" "")
BOTPRESS_REPO=$(prompt_input "BOTPRESS_REPO" "BotPress Repository" "https://github.com/Grupo1-Semestre3/salontime-bot-atendimento" "")
DB_REPO=$(prompt_input "DB_REPO" "Database Scripts Repository" "https://github.com/Grupo1-Semestre3/salontime-banco-dados" "")

print_section "Security Configuration"

ENABLE_WAF=$(prompt_yes_no "Enable AWS WAF (recommended for production)" "y")
SSH_ALLOWED_CIDR=$(prompt_input "SSH_ALLOWED_CIDR" "Allowed IP for SSH (0.0.0.0/0 for any)" "0.0.0.0/0" "validate_cidr")

print_section "Optional Configuration"

NOTIFICATION_EMAIL=$(prompt_input "NOTIFICATION_EMAIL" "Email for notifications (optional)" "" "")

# Generate .env file
print_section "Generating Configuration"

cat > "$ENV_FILE" << EOF
# ============================================
# SalonTime AWS Infrastructure Configuration
# ============================================
# Generated: $(date)

# AWS Configuration
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

# Project Configuration
PROJECT_NAME=$PROJECT_NAME
ENVIRONMENT=$ENVIRONMENT
PROJECT_TAG=SalonTime

# Network Configuration
VPC_CIDR=$VPC_CIDR
PUBLIC_SUBNET_CIDR=$PUBLIC_SUBNET_CIDR
PRIVATE_SUBNET1_CIDR=$PRIVATE_SUBNET1_CIDR
PRIVATE_SUBNET2_CIDR=$PRIVATE_SUBNET2_CIDR
AZ1=$AZ1
AZ2=$AZ2

# EC2 Configuration
FRONTEND_INSTANCE_TYPE=$FRONTEND_INSTANCE_TYPE
BACKEND_INSTANCE_TYPE=$BACKEND_INSTANCE_TYPE
BOTPRESS_INSTANCE_TYPE=$BOTPRESS_INSTANCE_TYPE
KEY_PAIR_NAME=$KEY_PAIR_NAME
KEY_FILE_PATH=$KEY_FILE_PATH
AMI_ID=

# RDS Configuration
DB_INSTANCE_CLASS=$DB_INSTANCE_CLASS
DB_ALLOCATED_STORAGE=20
DB_ENGINE_VERSION=8.0
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_PORT=3306
DB_MULTI_AZ=$DB_MULTI_AZ
DB_BACKUP_RETENTION=14

# Application Configuration
FRONTEND_PORT=3000
FRONTEND_REPO=$FRONTEND_REPO
FRONTEND_BRANCH=main
BACKEND_PORT=8080
BACKEND_REPO=$BACKEND_REPO
BACKEND_BRANCH=main
BOTPRESS_PORT=8081
BOTPRESS_REPO=$BOTPRESS_REPO
BOTPRESS_BRANCH=main
DB_REPO=$DB_REPO
DB_BRANCH=main

# Load Balancer Configuration
ALB_NAME=${PROJECT_NAME}-alb
HEALTH_CHECK_PATH=/
HEALTH_CHECK_INTERVAL=30
HEALTH_CHECK_TIMEOUT=5
HEALTHY_THRESHOLD=2
UNHEALTHY_THRESHOLD=3

# WAF Configuration
ENABLE_WAF=$ENABLE_WAF
WAF_RATE_LIMIT=2000

# Security Configuration
SSH_ALLOWED_CIDR=$SSH_ALLOWED_CIDR
DB_ALLOWED_CIDR=$VPC_CIDR

# Monitoring & Logging
ENABLE_CLOUDWATCH=true
LOG_RETENTION_DAYS=7

# Tags
TAGS_OWNER=DevOps Team
TAGS_COST_CENTER=Engineering
TAGS_PROJECT=SalonTime

# Notifications
NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL
SNS_TOPIC_ARN=

# Advanced Configuration
DOCKER_REGISTRY=
CUSTOM_DOMAIN=
ROUTE53_HOSTED_ZONE_ID=
SSL_CERTIFICATE_ARN=
EOF

chmod 600 "$ENV_FILE"

print_success "Configuration saved to .env"
echo ""

# Cost estimation
print_section "Estimated Monthly Costs"

if [ "$ENVIRONMENT" = "production" ]; then
    print_info "EC2 (3x $FRONTEND_INSTANCE_TYPE): ~\$90/month"
    print_info "RDS ($DB_INSTANCE_CLASS, Multi-AZ: $DB_MULTI_AZ): ~\$120/month"
    print_info "ALB: ~\$25/month"
    print_info "NAT Gateway: ~\$35/month"
    if [ "$ENABLE_WAF" = "true" ]; then
        print_info "WAF: ~\$15/month"
    fi
    print_info "Other (Data Transfer, CloudWatch): ~\$37/month"
    print_bold "TOTAL: ~\$322/month"
else
    print_info "EC2 (3x t3.small): ~\$45/month"
    print_info "RDS (db.t3.micro, Single-AZ): ~\$13/month"
    print_info "ALB: ~\$25/month"
    print_info "NAT Gateway: ~\$35/month"
    print_info "Other: ~\$7/month"
    print_bold "TOTAL: ~\$125/month"
fi

echo ""
print_header "Configuration Complete!"
print_info "Next steps:"
print_info "  1. Review the .env file"
print_info "  2. Run ./install-salontime.sh to start installation"
echo ""
