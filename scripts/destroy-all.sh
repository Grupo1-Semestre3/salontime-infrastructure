#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

print_header "SalonTime Infrastructure - Destroy All Resources"

print_warning "⚠️  WARNING: This will DELETE ALL AWS resources created by this automation!"
print_warning "This action cannot be undone!"
echo ""
read -p "Type 'DELETE' to confirm: " confirm1

if [ "$confirm1" != "DELETE" ]; then
    log_info "Destruction cancelled."
    exit 0
fi

read -p "Are you absolutely sure? Type 'YES' to confirm: " confirm2

if [ "$confirm2" != "YES" ]; then
    log_info "Destruction cancelled."
    exit 0
fi

log_section "Starting Resource Destruction"

# Load resource IDs from state
if [ ! -f "$STATE_FILE" ]; then
    log_error "State file not found. Cannot proceed with destruction."
    exit 1
fi

# Delete WAF
if WAF_ARN=$(jq -r '.waf_arn // empty' "$STATE_FILE"); then
    if [ -n "$WAF_ARN" ]; then
        log_info "Disassociating and deleting WAF..."
        ALB_ARN=$(jq -r '.alb_arn' "$STATE_FILE")
        aws wafv2 disassociate-web-acl --resource-arn "$ALB_ARN" --region "$AWS_REGION" 2>/dev/null || true
        
        WAF_ID=$(echo "$WAF_ARN" | awk -F'/' '{print $NF}')
        WAF_LOCK_TOKEN=$(aws wafv2 get-web-acl --scope REGIONAL --id "$WAF_ID" --name "${PROJECT_NAME}-waf" --region "$AWS_REGION" --query 'LockToken' --output text 2>/dev/null || echo "")
        if [ -n "$WAF_LOCK_TOKEN" ]; then
            aws wafv2 delete-web-acl --scope REGIONAL --id "$WAF_ID" --name "${PROJECT_NAME}-waf" --lock-token "$WAF_LOCK_TOKEN" --region "$AWS_REGION" 2>/dev/null || true
        fi
        log_success "WAF deleted"
    fi
fi

# Delete Load Balancer
if ALB_ARN=$(jq -r '.alb_arn // empty' "$STATE_FILE"); then
    if [ -n "$ALB_ARN" ]; then
        log_info "Deleting Load Balancer..."
        
        # Delete listeners
        LISTENER_ARN=$(jq -r '.listener_arn // empty' "$STATE_FILE")
        [ -n "$LISTENER_ARN" ] && aws elbv2 delete-listener --listener-arn "$LISTENER_ARN" 2>/dev/null || true
        
        # Delete target groups
        for TG_ARN in $(jq -r '.frontend_tg_arn, .backend_tg_arn, .botpress_tg_arn' "$STATE_FILE" 2>/dev/null); do
            [ -n "$TG_ARN" ] && [ "$TG_ARN" != "null" ] && aws elbv2 delete-target-group --target-group-arn "$TG_ARN" 2>/dev/null || true
        done
        
        aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" 2>/dev/null || true
        log_success "Load Balancer deleted"
        sleep 10
    fi
fi

# Terminate EC2 Instances
log_info "Terminating EC2 instances..."
for INSTANCE_ID in $(jq -r '.frontend_instance_id, .backend_instance_id, .botpress_instance_id' "$STATE_FILE" 2>/dev/null); do
    if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "null" ]; then
        aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" 2>/dev/null || true
    fi
done
log_success "EC2 instances terminated"

# Wait for instances to terminate
log_info "Waiting for instances to terminate..."
sleep 30

# Delete RDS
if DB_IDENTIFIER=$(jq -r '.db_identifier // empty' "$STATE_FILE"); then
    if [ -n "$DB_IDENTIFIER" ]; then
        log_info "Deleting RDS instance..."
        aws rds delete-db-instance \
            --db-instance-identifier "$DB_IDENTIFIER" \
            --skip-final-snapshot 2>/dev/null || true
        log_success "RDS instance deletion initiated"
    fi
fi

# Delete DB Subnet Group
aws rds delete-db-subnet-group --db-subnet-group-name "${PROJECT_NAME}-db-subnet-group" 2>/dev/null || true

# Delete NAT Gateway
if NAT_GW_ID=$(jq -r '.nat_gateway_id // empty' "$STATE_FILE"); then
    if [ -n "$NAT_GW_ID" ]; then
        log_info "Deleting NAT Gateway..."
        aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID" 2>/dev/null || true
        log_info "Waiting for NAT Gateway to delete..."
        sleep 30
    fi
fi

# Release Elastic IP
if EIP_ALLOC_ID=$(jq -r '.nat_eip_id // empty' "$STATE_FILE"); then
    if [ -n "$EIP_ALLOC_ID" ]; then
        log_info "Releasing Elastic IP..."
        aws ec2 release-address --allocation-id "$EIP_ALLOC_ID" 2>/dev/null || true
    fi
fi

# Delete Route Tables
for RT_ID in $(jq -r '.public_rt_id, .private_rt_id' "$STATE_FILE" 2>/dev/null); do
    if [ -n "$RT_ID" ] && [ "$RT_ID" != "null" ]; then
        aws ec2 delete-route-table --route-table-id "$RT_ID" 2>/dev/null || true
    fi
done

# Detach and Delete Internet Gateway
if IGW_ID=$(jq -r '.igw_id // empty' "$STATE_FILE"); then
    if [ -n "$IGW_ID" ]; then
        VPC_ID=$(jq -r '.vpc_id' "$STATE_FILE")
        log_info "Deleting Internet Gateway..."
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null || true
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" 2>/dev/null || true
    fi
fi

# Delete Subnets
for SUBNET_ID in $(jq -r '.public_subnet_id, .private_subnet1_id, .private_subnet2_id' "$STATE_FILE" 2>/dev/null); do
    if [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "null" ]; then
        aws ec2 delete-subnet --subnet-id "$SUBNET_ID" 2>/dev/null || true
    fi
done

# Delete Security Groups
sleep 10
for SG_ID in $(jq -r '.alb_sg_id, .ec2_sg_id, .rds_sg_id' "$STATE_FILE" 2>/dev/null); do
    if [ -n "$SG_ID" ] && [ "$SG_ID" != "null" ]; then
        aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || true
    fi
done

# Delete VPC
if VPC_ID=$(jq -r '.vpc_id // empty' "$STATE_FILE"); then
    if [ -n "$VPC_ID" ]; then
        log_info "Deleting VPC..."
        sleep 10
        aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null || true
        log_success "VPC deleted"
    fi
fi

# Clear state file
echo "{}" > "$STATE_FILE"

print_header "Destruction Complete"
log_success "All resources have been deleted"
log_info "State file cleared"
