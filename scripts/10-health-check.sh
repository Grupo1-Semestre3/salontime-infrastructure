#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$SCRIPT_DIR/utils/colors.sh"
source "$SCRIPT_DIR/utils/logger.sh"
set -a; source "$SCRIPT_DIR/.env"; set +a
STATE_FILE="$SCRIPT_DIR/state.json"

print_header "SalonTime Health Check"

FRONTEND_IP=$(jq -r '.frontend_public_ip' "$STATE_FILE")
BACKEND_IP=$(jq -r '.backend_public_ip' "$STATE_FILE")
BOTPRESS_IP=$(jq -r '.botpress_public_ip' "$STATE_FILE")
ALB_DNS=$(jq -r '.alb_dns' "$STATE_FILE")
DB_ENDPOINT=$(jq -r '.db_endpoint' "$STATE_FILE")

PASSED=0
FAILED=0

check_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    log_info "Checking $name..."
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null); then
        if [ "$response" = "$expected_code" ]; then
            log_success "$name is healthy (HTTP $response)"
            ((PASSED++))
            return 0
        else
            log_warning "$name returned HTTP $response (expected $expected_code)"
            ((FAILED++))
            return 1
        fi
    else
        log_error "$name is unreachable"
        ((FAILED++))
        return 1
    fi
}

log_section "EC2 Instances"
check_endpoint "Frontend Instance" "http://$FRONTEND_IP:$FRONTEND_PORT" || true
check_endpoint "Backend Instance" "http://$BACKEND_IP:$BACKEND_PORT/actuator/health" || true
check_endpoint "BotPress Instance" "http://$BOTPRESS_IP:$BOTPRESS_PORT" || true

log_section "Load Balancer"
if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "null" ]; then
    check_endpoint "Frontend via ALB" "http://$ALB_DNS/" || true
    check_endpoint "Backend via ALB" "http://$ALB_DNS/api/" || true
    check_endpoint "BotPress via ALB" "http://$ALB_DNS/bot/" || true
else
    log_warning "ALB DNS not available yet"
fi

log_section "Database"
if [ -n "$DB_ENDPOINT" ] && [ "$DB_ENDPOINT" != "null" ]; then
    log_info "Database endpoint: $DB_ENDPOINT:$DB_PORT"
    log_success "Database is provisioned"
    ((PASSED++))
else
    log_error "Database endpoint not found"
    ((FAILED++))
fi

echo ""
print_header "Health Check Summary"
print_info "Passed: $PASSED"
if [ $FAILED -gt 0 ]; then
    print_warning "Failed: $FAILED"
else
    print_success "Failed: $FAILED"
fi

if [ $FAILED -eq 0 ]; then
    print_box "All systems operational!"
    exit 0
else
    print_warning "Some checks failed. Review logs for details."
    exit 1
fi
