#!/bin/bash

# Input validation functions

# Validate CIDR format
validate_cidr() {
    local cidr=$1
    
    # Check basic format (X.X.X.X/Y)
    if [[ ! $cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi
    
    # Extract IP and prefix
    local ip=${cidr%/*}
    local prefix=${cidr#*/}
    
    # Validate each octet
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if [ "$octet" -gt 255 ]; then
            return 1
        fi
    done
    
    # Validate prefix (0-32)
    if [ "$prefix" -gt 32 ] || [ "$prefix" -lt 0 ]; then
        return 1
    fi
    
    return 0
}

# Validate email format
validate_email() {
    local email=$1
    
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate password strength
validate_password() {
    local password=$1
    local min_length=${2:-8}
    
    # Check minimum length
    if [ ${#password} -lt $min_length ]; then
        echo "Password must be at least $min_length characters long"
        return 1
    fi
    
    # Check for at least one letter
    if [[ ! $password =~ [a-zA-Z] ]]; then
        echo "Password must contain at least one letter"
        return 1
    fi
    
    # Check for at least one number
    if [[ ! $password =~ [0-9] ]]; then
        echo "Password must contain at least one number"
        return 1
    fi
    
    return 0
}

# Validate AWS region format
validate_aws_region() {
    local region=$1
    local valid_regions=(
        "us-east-1" "us-east-2" "us-west-1" "us-west-2"
        "eu-west-1" "eu-west-2" "eu-west-3" "eu-central-1"
        "ap-southeast-1" "ap-southeast-2" "ap-northeast-1" "ap-northeast-2"
        "sa-east-1" "ca-central-1"
    )
    
    for valid_region in "${valid_regions[@]}"; do
        if [ "$region" = "$valid_region" ]; then
            return 0
        fi
    done
    
    return 1
}

# Validate instance type
validate_instance_type() {
    local instance_type=$1
    
    if [[ $instance_type =~ ^(t2|t3|t3a|m5|m5a|c5|c5a|r5|r5a)\.(nano|micro|small|medium|large|xlarge|2xlarge)$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate RDS instance class
validate_rds_instance_class() {
    local instance_class=$1
    
    if [[ $instance_class =~ ^db\.(t2|t3|m5|r5)\.(micro|small|medium|large|xlarge|2xlarge)$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate port number
validate_port() {
    local port=$1
    
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Validate environment (dev/staging/prod)
validate_environment() {
    local env=$1
    
    case $env in
        dev|development|staging|prod|production)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate yes/no input
validate_yes_no() {
    local input=$1
    
    case ${input,,} in
        y|yes|true|1)
            echo "yes"
            return 0
            ;;
        n|no|false|0)
            echo "no"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate non-empty string
validate_not_empty() {
    local value=$1
    local field_name=${2:-"Field"}
    
    if [ -z "$value" ]; then
        echo "$field_name cannot be empty"
        return 1
    fi
    
    return 0
}

# Validate alphanumeric with hyphens (for resource names)
validate_resource_name() {
    local name=$1
    
    if [[ $name =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate S3 bucket name
validate_s3_bucket_name() {
    local bucket=$1
    
    # S3 bucket naming rules
    if [[ ! $bucket =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
        return 1
    fi
    
    # No consecutive dots
    if [[ $bucket =~ \.\. ]]; then
        return 1
    fi
    
    # No IP address format
    if [[ $bucket =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate GitHub repository URL
validate_github_repo() {
    local repo=$1
    
    if [[ $repo =~ ^https://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        return 0
    else
        return 1
    fi
}
