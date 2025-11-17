#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/aws-helpers.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

VPC_ID=$(jq -r '.vpc_id' "$STATE_FILE")
PUBLIC_SUBNET_ID=$(jq -r '.public_subnet_id' "$STATE_FILE")
PRIVATE_SUBNET1_ID=$(jq -r '.private_subnet1_id' "$STATE_FILE")
ALB_SG_ID=$(jq -r '.alb_sg_id' "$STATE_FILE")
FRONTEND_INSTANCE_ID=$(jq -r '.frontend_instance_id' "$STATE_FILE")
BACKEND_INSTANCE_ID=$(jq -r '.backend_instance_id' "$STATE_FILE")
BOTPRESS_INSTANCE_ID=$(jq -r '.botpress_instance_id' "$STATE_FILE")

log_section "Creating Application Load Balancer"

ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets "$PUBLIC_SUBNET_ID" "$PRIVATE_SUBNET1_ID" \
    --security-groups "$ALB_SG_ID" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags "Key=Name,Value=$ALB_NAME" "Key=Project,Value=$PROJECT_TAG" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

log_success "ALB created: $ALB_ARN"

log_info "Waiting for ALB to be active..."
wait_for_resource "load-balancer" "$ALB_ARN" 300

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

log_success "ALB DNS: $ALB_DNS"

log_section "Creating Target Groups"

# Frontend Target Group
FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
    --name "${PROJECT_NAME}-frontend-tg" \
    --protocol HTTP \
    --port "$FRONTEND_PORT" \
    --vpc-id "$VPC_ID" \
    --health-check-path "$HEALTH_CHECK_PATH" \
    --health-check-interval-seconds "$HEALTH_CHECK_INTERVAL" \
    --health-check-timeout-seconds "$HEALTH_CHECK_TIMEOUT" \
    --healthy-threshold-count "$HEALTHY_THRESHOLD" \
    --unhealthy-threshold-count "$UNHEALTHY_THRESHOLD" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 register-targets --target-group-arn "$FRONTEND_TG_ARN" --targets "Id=$FRONTEND_INSTANCE_ID"
log_success "Frontend Target Group created"

# Backend Target Group
BACKEND_TG_ARN=$(aws elbv2 create-target-group \
    --name "${PROJECT_NAME}-backend-tg" \
    --protocol HTTP \
    --port "$BACKEND_PORT" \
    --vpc-id "$VPC_ID" \
    --health-check-path "/actuator/health" \
    --health-check-interval-seconds "$HEALTH_CHECK_INTERVAL" \
    --health-check-timeout-seconds "$HEALTH_CHECK_TIMEOUT" \
    --healthy-threshold-count "$HEALTHY_THRESHOLD" \
    --unhealthy-threshold-count "$UNHEALTHY_THRESHOLD" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 register-targets --target-group-arn "$BACKEND_TG_ARN" --targets "Id=$BACKEND_INSTANCE_ID"
log_success "Backend Target Group created"

# BotPress Target Group
BOTPRESS_TG_ARN=$(aws elbv2 create-target-group \
    --name "${PROJECT_NAME}-botpress-tg" \
    --protocol HTTP \
    --port "$BOTPRESS_PORT" \
    --vpc-id "$VPC_ID" \
    --health-check-path "/" \
    --health-check-interval-seconds "$HEALTH_CHECK_INTERVAL" \
    --health-check-timeout-seconds "$HEALTH_CHECK_TIMEOUT" \
    --healthy-threshold-count "$HEALTHY_THRESHOLD" \
    --unhealthy-threshold-count "$UNHEALTHY_THRESHOLD" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 register-targets --target-group-arn "$BOTPRESS_TG_ARN" --targets "Id=$BOTPRESS_INSTANCE_ID"
log_success "BotPress Target Group created"

log_section "Creating Listeners and Rules"

# Create HTTP listener
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$FRONTEND_TG_ARN" \
    --query 'Listeners[0].ListenerArn' \
    --output text)

log_success "HTTP Listener created"

# Create path-based routing rules
# Rule for /api/* -> Backend
aws elbv2 create-rule \
    --listener-arn "$LISTENER_ARN" \
    --priority 10 \
    --conditions "Field=path-pattern,Values=/api/*" \
    --actions "Type=forward,TargetGroupArn=$BACKEND_TG_ARN"

# Rule for /bot/* -> BotPress
aws elbv2 create-rule \
    --listener-arn "$LISTENER_ARN" \
    --priority 20 \
    --conditions "Field=path-pattern,Values=/bot/*" \
    --actions "Type=forward,TargetGroupArn=$BOTPRESS_TG_ARN"

log_success "Routing rules created"

# Save to state
jq --arg alb "$ALB_ARN" --arg dns "$ALB_DNS" --arg listener "$LISTENER_ARN" \
   --arg ftg "$FRONTEND_TG_ARN" --arg btg "$BACKEND_TG_ARN" --arg ptg "$BOTPRESS_TG_ARN" \
   '.alb_arn = $alb | .alb_dns = $dns | .listener_arn = $listener | 
    .frontend_tg_arn = $ftg | .backend_tg_arn = $btg | .botpress_tg_arn = $ptg' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_success "Application Load Balancer setup complete"
