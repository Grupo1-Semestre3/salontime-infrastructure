#!/bin/bash

# SSH helper functions for remote command execution

# Execute command via SSH
ssh_exec() {
    local host=$1
    local key_file=$2
    local command=$3
    local user=${4:-ec2-user}
    
    ssh -i "$key_file" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "$user@$host" \
        "$command"
}

# Copy file to remote host
scp_to_remote() {
    local source=$1
    local host=$2
    local destination=$3
    local key_file=$4
    local user=${5:-ec2-user}
    
    scp -i "$key_file" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$source" \
        "$user@$host:$destination"
}

# Copy file from remote host
scp_from_remote() {
    local host=$1
    local source=$2
    local destination=$3
    local key_file=$4
    local user=${5:-ec2-user}
    
    scp -i "$key_file" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$user@$host:$source" \
        "$destination"
}

# Wait for SSH to be available
wait_for_ssh() {
    local host=$1
    local key_file=$2
    local max_wait=${3:-300}
    local user=${4:-ec2-user}
    
    log_info "Waiting for SSH access to $host..."
    
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $max_wait ]; do
        if ssh -i "$key_file" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o BatchMode=yes \
            "$user@$host" "echo SSH_OK" &> /dev/null; then
            log_success "SSH is available on $host"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    log_error "Timeout waiting for SSH on $host"
    return 1
}

# Install Docker on remote host
install_docker_remote() {
    local host=$1
    local key_file=$2
    local user=${3:-ec2-user}
    
    log_info "Installing Docker on $host..."
    
    # Install Docker
    ssh_exec "$host" "$key_file" "
        sudo yum update -y && \
        sudo yum install -y docker && \
        sudo systemctl start docker && \
        sudo systemctl enable docker && \
        sudo usermod -aG docker $user
    " "$user"
    
    if [ $? -eq 0 ]; then
        log_success "Docker installed on $host"
        return 0
    else
        log_error "Failed to install Docker on $host"
        return 1
    fi
}

# Install Docker Compose on remote host
install_docker_compose_remote() {
    local host=$1
    local key_file=$2
    local user=${3:-ec2-user}
    
    log_info "Installing Docker Compose on $host..."
    
    ssh_exec "$host" "$key_file" "
        sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" \
            -o /usr/local/bin/docker-compose && \
        sudo chmod +x /usr/local/bin/docker-compose && \
        docker-compose --version
    " "$user"
    
    if [ $? -eq 0 ]; then
        log_success "Docker Compose installed on $host"
        return 0
    else
        log_error "Failed to install Docker Compose on $host"
        return 1
    fi
}

# Deploy Docker container on remote host
deploy_container_remote() {
    local host=$1
    local key_file=$2
    local compose_file=$3
    local user=${4:-ec2-user}
    local app_dir=${5:-/home/ec2-user/app}
    
    log_info "Deploying container on $host..."
    
    # Create app directory
    ssh_exec "$host" "$key_file" "mkdir -p $app_dir" "$user"
    
    # Copy docker-compose file
    scp_to_remote "$compose_file" "$host" "$app_dir/docker-compose.yml" "$key_file" "$user"
    
    # Deploy container
    ssh_exec "$host" "$key_file" "
        cd $app_dir && \
        docker-compose pull && \
        docker-compose up -d
    " "$user"
    
    if [ $? -eq 0 ]; then
        log_success "Container deployed on $host"
        return 0
    else
        log_error "Failed to deploy container on $host"
        return 1
    fi
}

# Check container health on remote host
check_container_health_remote() {
    local host=$1
    local key_file=$2
    local container_name=$3
    local user=${4:-ec2-user}
    
    local status=$(ssh_exec "$host" "$key_file" \
        "docker ps --filter name=$container_name --format '{{.Status}}'" "$user")
    
    if [[ $status == *"Up"* ]]; then
        log_success "Container $container_name is healthy on $host"
        return 0
    else
        log_error "Container $container_name is not running on $host"
        return 1
    fi
}

# Get container logs from remote host
get_container_logs_remote() {
    local host=$1
    local key_file=$2
    local container_name=$3
    local lines=${4:-100}
    local user=${5:-ec2-user}
    
    ssh_exec "$host" "$key_file" \
        "docker logs --tail $lines $container_name" "$user"
}

# Restart container on remote host
restart_container_remote() {
    local host=$1
    local key_file=$2
    local container_name=$3
    local user=${4:-ec2-user}
    
    log_info "Restarting container $container_name on $host..."
    
    ssh_exec "$host" "$key_file" "docker restart $container_name" "$user"
    
    if [ $? -eq 0 ]; then
        log_success "Container $container_name restarted on $host"
        return 0
    else
        log_error "Failed to restart container $container_name on $host"
        return 1
    fi
}

# Stop and remove container on remote host
remove_container_remote() {
    local host=$1
    local key_file=$2
    local container_name=$3
    local user=${4:-ec2-user}
    
    log_info "Removing container $container_name from $host..."
    
    ssh_exec "$host" "$key_file" "
        docker stop $container_name 2>/dev/null
        docker rm $container_name 2>/dev/null
    " "$user"
    
    log_success "Container $container_name removed from $host"
}
