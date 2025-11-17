#!/bin/bash

# Setup VPC and Network Infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
source "$SCRIPT_DIR/utils/aws-helpers.sh"

# Load configuration
set -a
source "$SCRIPT_DIR/.env"
set +a

STATE_FILE="$SCRIPT_DIR/state.json"

log_section "Creating VPC"

# Check if VPC already exists
EXISTING_VPC=$(get_resource_by_tag "vpc" "Name" "${PROJECT_NAME}-vpc")

if [ "$EXISTING_VPC" != "None" ] && [ -n "$EXISTING_VPC" ]; then
    log_warning "VPC already exists: $EXISTING_VPC"
    VPC_ID=$EXISTING_VPC
else
    # Create VPC
    log_info "Creating VPC with CIDR: $VPC_CIDR"
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block "$VPC_CIDR" \
        --region "$AWS_REGION" \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc},{Key=Project,Value=$PROJECT_TAG},{Key=Environment,Value=$ENVIRONMENT}]" \
        --query 'Vpc.VpcId' \
        --output text)
    
    log_success "VPC created: $VPC_ID"
    
    # Enable DNS
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
fi

# Save to state
jq --arg vpc "$VPC_ID" '.vpc_id = $vpc' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_section "Creating Subnets"

# Public Subnet
EXISTING_PUBLIC=$(get_resource_by_tag "subnet" "Name" "${PROJECT_NAME}-public-subnet")
if [ "$EXISTING_PUBLIC" != "None" ] && [ -n "$EXISTING_PUBLIC" ]; then
    PUBLIC_SUBNET_ID=$EXISTING_PUBLIC
    log_warning "Public subnet already exists: $PUBLIC_SUBNET_ID"
else
    PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PUBLIC_SUBNET_CIDR" \
        --availability-zone "$AZ1" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-subnet},{Key=Project,Value=$PROJECT_TAG}]" \
        --query 'Subnet.SubnetId' \
        --output text)
    log_success "Public subnet created: $PUBLIC_SUBNET_ID"
fi

# Private Subnet 1
EXISTING_PRIVATE1=$(get_resource_by_tag "subnet" "Name" "${PROJECT_NAME}-private-subnet-1")
if [ "$EXISTING_PRIVATE1" != "None" ] && [ -n "$EXISTING_PRIVATE1" ]; then
    PRIVATE_SUBNET1_ID=$EXISTING_PRIVATE1
    log_warning "Private subnet 1 already exists: $PRIVATE_SUBNET1_ID"
else
    PRIVATE_SUBNET1_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PRIVATE_SUBNET1_CIDR" \
        --availability-zone "$AZ1" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1},{Key=Project,Value=$PROJECT_TAG}]" \
        --query 'Subnet.SubnetId' \
        --output text)
    log_success "Private subnet 1 created: $PRIVATE_SUBNET1_ID"
fi

# Private Subnet 2
EXISTING_PRIVATE2=$(get_resource_by_tag "subnet" "Name" "${PROJECT_NAME}-private-subnet-2")
if [ "$EXISTING_PRIVATE2" != "None" ] && [ -n "$EXISTING_PRIVATE2" ]; then
    PRIVATE_SUBNET2_ID=$EXISTING_PRIVATE2
    log_warning "Private subnet 2 already exists: $PRIVATE_SUBNET2_ID"
else
    PRIVATE_SUBNET2_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$PRIVATE_SUBNET2_CIDR" \
        --availability-zone "$AZ2" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-2},{Key=Project,Value=$PROJECT_TAG}]" \
        --query 'Subnet.SubnetId' \
        --output text)
    log_success "Private subnet 2 created: $PRIVATE_SUBNET2_ID"
fi

# Save subnets to state
jq --arg pub "$PUBLIC_SUBNET_ID" \
   --arg priv1 "$PRIVATE_SUBNET1_ID" \
   --arg priv2 "$PRIVATE_SUBNET2_ID" \
   '.public_subnet_id = $pub | .private_subnet1_id = $priv1 | .private_subnet2_id = $priv2' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_section "Creating Internet Gateway"

EXISTING_IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_IGW" != "None" ] && [ -n "$EXISTING_IGW" ]; then
    IGW_ID=$EXISTING_IGW
    log_warning "Internet Gateway already exists: $IGW_ID"
else
    IGW_ID=$(aws ec2 create-internet-gateway \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw},{Key=Project,Value=$PROJECT_TAG}]" \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)
    
    aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
    log_success "Internet Gateway created and attached: $IGW_ID"
fi

jq --arg igw "$IGW_ID" '.igw_id = $igw' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_section "Allocating Elastic IP for NAT Gateway"

EXISTING_EIP=$(jq -r '.nat_eip_id // empty' "$STATE_FILE")
if [ -n "$EXISTING_EIP" ]; then
    EIP_ALLOC_ID=$EXISTING_EIP
    log_warning "Elastic IP already allocated: $EIP_ALLOC_ID"
else
    EIP_ALLOC_ID=$(aws ec2 allocate-address \
        --domain vpc \
        --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat-eip},{Key=Project,Value=$PROJECT_TAG}]" \
        --query 'AllocationId' \
        --output text)
    log_success "Elastic IP allocated: $EIP_ALLOC_ID"
fi

jq --arg eip "$EIP_ALLOC_ID" '.nat_eip_id = $eip' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_section "Creating NAT Gateway"

EXISTING_NAT=$(aws ec2 describe-nat-gateways \
    --filter "Name=subnet-id,Values=$PUBLIC_SUBNET_ID" "Name=state,Values=available,pending" \
    --query 'NatGateways[0].NatGatewayId' \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_NAT" != "None" ] && [ -n "$EXISTING_NAT" ]; then
    NAT_GW_ID=$EXISTING_NAT
    log_warning "NAT Gateway already exists: $NAT_GW_ID"
else
    NAT_GW_ID=$(aws ec2 create-nat-gateway \
        --subnet-id "$PUBLIC_SUBNET_ID" \
        --allocation-id "$EIP_ALLOC_ID" \
        --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat},{Key=Project,Value=$PROJECT_TAG}]" \
        --query 'NatGateway.NatGatewayId' \
        --output text)
    
    log_success "NAT Gateway created: $NAT_GW_ID"
    log_info "Waiting for NAT Gateway to become available..."
    wait_for_resource "nat-gateway" "$NAT_GW_ID" 300
fi

jq --arg nat "$NAT_GW_ID" '.nat_gateway_id = $nat' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_section "Creating Route Tables"

# Public Route Table
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-rt},{Key=Project,Value=$PROJECT_TAG}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

aws ec2 create-route --route-table-id "$PUBLIC_RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --subnet-id "$PUBLIC_SUBNET_ID" --route-table-id "$PUBLIC_RT_ID"
log_success "Public route table created: $PUBLIC_RT_ID"

# Private Route Table
PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-rt},{Key=Project,Value=$PROJECT_TAG}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

aws ec2 create-route --route-table-id "$PRIVATE_RT_ID" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET1_ID" --route-table-id "$PRIVATE_RT_ID"
aws ec2 associate-route-table --subnet-id "$PRIVATE_SUBNET2_ID" --route-table-id "$PRIVATE_RT_ID"
log_success "Private route table created: $PRIVATE_RT_ID"

# Save route tables to state
jq --arg pubrt "$PUBLIC_RT_ID" --arg privrt "$PRIVATE_RT_ID" \
   '.public_rt_id = $pubrt | .private_rt_id = $privrt' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

log_success "VPC and network infrastructure setup complete"
