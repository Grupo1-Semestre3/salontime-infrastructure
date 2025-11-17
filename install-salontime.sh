#!/bin/bash

# SalonTime AWS Infrastructure - Main Installation Script
# Orchestrates the complete automated installation

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/validators.sh"
source "$SCRIPT_DIR/utils/aws-helpers.sh"

# Initialize logger
init_logger

# Print banner
print_header "SalonTime AWS Infrastructure - Automated Installation"
print_info "Version: 1.0"
print_info "Estimated Time: 35-45 minutes"
echo ""

# Check prerequisites
print_section "Checking Prerequisites"

# Check for .env file
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log_error "Configuration file .env not found."
    print_info "Please run ./configure.sh first to generate the configuration."
    exit 1
fi

# Load environment variables
log_info "Loading configuration from .env..."
set -a
source "$SCRIPT_DIR/.env"
set +a
log_success "Configuration loaded"

# Check AWS CLI
if ! check_aws_cli; then
    exit 1
fi

# Check AWS credentials
if ! check_aws_credentials; then
    exit 1
fi

# Check jq
if ! command -v jq &> /dev/null; then
    log_error "jq not found. Please install jq: sudo yum install -y jq"
    exit 1
fi
log_success "jq is installed"

# Check SSH key
if [ ! -f "$KEY_FILE_PATH" ]; then
    log_error "SSH key not found: $KEY_FILE_PATH"
    exit 1
fi
log_success "SSH key found: $KEY_FILE_PATH"

# Confirm installation
echo ""
print_box "Ready to Install SalonTime Infrastructure"
echo ""
print_info "Environment: $ENVIRONMENT"
print_info "Region: $AWS_REGION"
print_info "Project: $PROJECT_NAME"
echo ""
print_warning "This will create AWS resources that incur costs."
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Installation cancelled by user."
    exit 0
fi

# Create state file
STATE_FILE="$SCRIPT_DIR/state.json"
if [ ! -f "$STATE_FILE" ]; then
    echo "{}" > "$STATE_FILE"
fi

# Installation steps
TOTAL_STEPS=10
CURRENT_STEP=0

# Function to run installation step
run_step() {
    local step_num=$1
    local step_name=$2
    local script_file=$3
    
    CURRENT_STEP=$step_num
    print_progress $CURRENT_STEP $TOTAL_STEPS "$step_name"
    
    log_header "Step $step_num/$TOTAL_STEPS: $step_name"
    
    if [ -f "$SCRIPT_DIR/scripts/$script_file" ]; then
        bash "$SCRIPT_DIR/scripts/$script_file"
        if [ $? -eq 0 ]; then
            log_success "Step $step_num completed: $step_name"
        else
            log_error "Step $step_num failed: $step_name"
            log_error "Check logs at: $(get_log_file)"
            exit 1
        fi
    else
        log_error "Script not found: scripts/$script_file"
        exit 1
    fi
}

# Start installation
START_TIME=$(date +%s)

log_header "Starting SalonTime Infrastructure Installation"

# Step 1: Setup VPC
run_step 1 "Setting up VPC and Network" "01-setup-vpc.sh"

# Step 2: Setup Security Groups
run_step 2 "Configuring Security Groups" "02-setup-security-groups.sh"

# Step 3: Setup RDS
run_step 3 "Provisioning RDS MySQL Database" "03-setup-rds.sh"

# Step 4: Create EC2 Instances
run_step 4 "Creating EC2 Instances" "04-create-ec2-instances.sh"

# Step 5: Deploy Frontend
run_step 5 "Deploying Frontend Application" "05-deploy-frontend.sh"

# Step 6: Deploy Backend
run_step 6 "Deploying Backend Application" "06-deploy-backend.sh"

# Step 7: Deploy BotPress
run_step 7 "Deploying BotPress Chatbot" "07-deploy-botpress.sh"

# Step 8: Setup Load Balancer
run_step 8 "Configuring Application Load Balancer" "08-setup-loadbalancer.sh"

# Step 9: Setup WAF
if [ "$ENABLE_WAF" = "true" ]; then
    run_step 9 "Configuring AWS WAF" "09-setup-waf.sh"
else
    log_info "WAF disabled, skipping step 9"
    print_progress 9 $TOTAL_STEPS "WAF Configuration (Skipped)"
fi

# Step 10: Health Check
run_step 10 "Running Health Checks" "10-health-check.sh"

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Installation complete
echo ""
print_header "Installation Complete!"
print_success "SalonTime infrastructure deployed successfully!"
echo ""
print_info "Duration: ${MINUTES}m ${SECONDS}s"
echo ""

# Display access information
if [ -f "$STATE_FILE" ]; then
    ALB_DNS=$(jq -r '.alb_dns // empty' "$STATE_FILE")
    if [ -n "$ALB_DNS" ]; then
        print_section "Access Information"
        print_info "Application Load Balancer: http://$ALB_DNS"
        print_info "Frontend: http://$ALB_DNS/"
        print_info "Backend API: http://$ALB_DNS/api/"
        print_info "BotPress: http://$ALB_DNS/bot/"
        echo ""
    fi
fi

print_section "Next Steps"
print_info "1. Access your application via the Load Balancer URL"
print_info "2. Run ./scripts/10-health-check.sh anytime to verify system health"
print_info "3. Use ./scripts/update-*.sh to update individual components"
print_info "4. View logs at: $(get_log_file)"
echo ""

print_section "Resource Management"
print_info "State file: $STATE_FILE"
print_info "To destroy all resources: ./scripts/destroy-all.sh"
echo ""

log_info "Installation log saved to: $(get_log_file)"

print_box "Thank you for using SalonTime Infrastructure Automation!"
