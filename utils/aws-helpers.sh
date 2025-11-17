#!/bin/bash

# AWS CLI helper functions with retry logic and error handling

# Retry AWS CLI command with exponential backoff
aws_retry() {
    local max_attempts=${1:-3}
    local timeout=${2:-1}
    local command="${@:3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if output=$($command 2>&1); then
            echo "$output"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                log_warning "Attempt $attempt failed. Retrying in ${timeout}s..."
                sleep $timeout
                timeout=$((timeout * 2))
            else
                log_error "Command failed after $max_attempts attempts: $command"
                echo "$output" >&2
                return 1
            fi
        fi
        attempt=$((attempt + 1))
    done
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI v2."
        return 1
    fi
    
    local version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    log_info "AWS CLI version: $version"
    return 0
}

# Check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        return 1
    fi
    
    local identity=$(aws sts get-caller-identity)
    local account=$(echo "$identity" | jq -r '.Account')
    local arn=$(echo "$identity" | jq -r '.Arn')
    
    log_success "AWS credentials valid"
    log_info "Account: $account"
    log_info "Identity: $arn"
    return 0
}

# Wait for resource to be available
wait_for_resource() {
    local resource_type=$1
    local resource_id=$2
    local max_wait=${3:-300}  # 5 minutes default
    local check_interval=${4:-10}
    
    log_info "Waiting for $resource_type $resource_id to be ready..."
    
    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        case $resource_type in
            "ec2-instance")
                local state=$(aws ec2 describe-instances --instance-ids "$resource_id" \
                    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
                [ "$state" = "running" ] && return 0
                ;;
            "rds-instance")
                local status=$(aws rds describe-db-instances --db-instance-identifier "$resource_id" \
                    --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)
                [ "$status" = "available" ] && return 0
                ;;
            "load-balancer")
                local state=$(aws elbv2 describe-load-balancers --load-balancer-arns "$resource_id" \
                    --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null)
                [ "$state" = "active" ] && return 0
                ;;
            "nat-gateway")
                local state=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$resource_id" \
                    --query 'NatGateways[0].State' --output text 2>/dev/null)
                [ "$state" = "available" ] && return 0
                ;;
        esac
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        echo -n "."
    done
    
    echo ""
    log_error "Timeout waiting for $resource_type $resource_id"
    return 1
}

# Get resource by tag
get_resource_by_tag() {
    local resource_type=$1
    local tag_key=$2
    local tag_value=$3
    
    case $resource_type in
        "vpc")
            aws ec2 describe-vpcs \
                --filters "Name=tag:$tag_key,Values=$tag_value" \
                --query 'Vpcs[0].VpcId' --output text
            ;;
        "subnet")
            aws ec2 describe-subnets \
                --filters "Name=tag:$tag_key,Values=$tag_value" \
                --query 'Subnets[0].SubnetId' --output text
            ;;
        "security-group")
            aws ec2 describe-security-groups \
                --filters "Name=tag:$tag_key,Values=$tag_value" \
                --query 'SecurityGroups[0].GroupId' --output text
            ;;
        "instance")
            aws ec2 describe-instances \
                --filters "Name=tag:$tag_key,Values=$tag_value" "Name=instance-state-name,Values=running,pending" \
                --query 'Reservations[0].Instances[0].InstanceId' --output text
            ;;
    esac
}

# Check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_id=$2
    
    case $resource_type in
        "vpc")
            aws ec2 describe-vpcs --vpc-ids "$resource_id" &> /dev/null
            ;;
        "subnet")
            aws ec2 describe-subnets --subnet-ids "$resource_id" &> /dev/null
            ;;
        "security-group")
            aws ec2 describe-security-groups --group-ids "$resource_id" &> /dev/null
            ;;
        "instance")
            aws ec2 describe-instances --instance-ids "$resource_id" &> /dev/null
            ;;
        "rds")
            aws rds describe-db-instances --db-instance-identifier "$resource_id" &> /dev/null
            ;;
        "load-balancer")
            aws elbv2 describe-load-balancers --load-balancer-arns "$resource_id" &> /dev/null
            ;;
    esac
    
    return $?
}

# Tag resource
tag_resource() {
    local resource_id=$1
    local key=$2
    local value=$3
    
    aws ec2 create-tags \
        --resources "$resource_id" \
        --tags "Key=$key,Value=$value" \
        2>/dev/null
}

# Get latest Amazon Linux 2 AMI
get_latest_ami() {
    local region=${1:-us-east-1}
    
    aws ec2 describe-images \
        --region "$region" \
        --owners amazon \
        --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
                  "Name=state,Values=available" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text
}

# Check VPC quota
check_vpc_quota() {
    local region=${1:-us-east-1}
    
    local current=$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)' --output text)
    log_info "Current VPCs in region: $current/5 (default quota)"
    
    if [ "$current" -ge 5 ]; then
        log_warning "Approaching VPC quota limit. Consider requesting increase."
        return 1
    fi
    
    return 0
}
