#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

ALB_ARN=$(jq -r '.alb_arn' "$STATE_FILE")

log_section "Creating AWS WAF Web ACL"

# Create Web ACL
WAF_ID=$(aws wafv2 create-web-acl \
    --name "${PROJECT_NAME}-waf" \
    --region "$AWS_REGION" \
    --scope REGIONAL \
    --default-action Allow={} \
    --rules '[
        {
            "Name": "RateLimitRule",
            "Priority": 1,
            "Statement": {
                "RateBasedStatement": {
                    "Limit": '"$WAF_RATE_LIMIT"',
                    "AggregateKeyType": "IP"
                }
            },
            "Action": {
                "Block": {}
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "RateLimitRule"
            }
        },
        {
            "Name": "AWSManagedRulesCommonRuleSet",
            "Priority": 2,
            "Statement": {
                "ManagedRuleGroupStatement": {
                    "VendorName": "AWS",
                    "Name": "AWSManagedRulesCommonRuleSet"
                }
            },
            "OverrideAction": {
                "None": {}
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "AWSManagedRulesCommonRuleSet"
            }
        }
    ]' \
    --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName="${PROJECT_NAME}-waf" \
    --query 'Summary.Id' \
    --output text)

log_success "WAF Web ACL created: $WAF_ID"

# Get Web ACL ARN
WAF_ARN=$(aws wafv2 list-web-acls --scope REGIONAL --region "$AWS_REGION" \
    --query "WebACLs[?Name=='${PROJECT_NAME}-waf'].ARN | [0]" --output text)

# Associate WAF with ALB
aws wafv2 associate-web-acl \
    --web-acl-arn "$WAF_ARN" \
    --resource-arn "$ALB_ARN" \
    --region "$AWS_REGION"

log_success "WAF associated with ALB"

jq --arg waf "$WAF_ARN" '.waf_arn = $waf' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_success "AWS WAF setup complete"
