#!/bin/bash

# Logger utility for dual output (terminal + file)
# Logs are saved to logs/ directory with automatic rotation

# Source colors if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
fi

# Initialize logger
LOG_DIR="${LOG_DIR:-./logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/salontime-$(date +%Y%m%d-%H%M%S).log}"

init_logger() {
    mkdir -p "$LOG_DIR"
    
    # Rotate old logs (keep last 10)
    local log_count=$(ls -1 "$LOG_DIR"/salontime-*.log 2>/dev/null | wc -l)
    if [ "$log_count" -gt 10 ]; then
        ls -1t "$LOG_DIR"/salontime-*.log | tail -n +11 | xargs rm -f
    fi
    
    # Create new log file
    touch "$LOG_FILE"
    log_info "Logger initialized: $LOG_FILE"
}

# Log to file with timestamp
log_to_file() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Log levels
log_info() {
    local message=$1
    log_to_file "INFO" "$message"
    if type print_info &>/dev/null; then
        print_info "$message"
    else
        echo "ℹ $message"
    fi
}

log_success() {
    local message=$1
    log_to_file "SUCCESS" "$message"
    if type print_success &>/dev/null; then
        print_success "$message"
    else
        echo "✓ $message"
    fi
}

log_warning() {
    local message=$1
    log_to_file "WARNING" "$message"
    if type print_warning &>/dev/null; then
        print_warning "$message"
    else
        echo "⚠ $message"
    fi
}

log_error() {
    local message=$1
    log_to_file "ERROR" "$message"
    if type print_error &>/dev/null; then
        print_error "$message"
    else
        echo "✗ $message" >&2
    fi
}

log_header() {
    local message=$1
    log_to_file "HEADER" "$message"
    if type print_header &>/dev/null; then
        print_header "$message"
    else
        echo ""
        echo "========================================"
        echo "$message"
        echo "========================================"
        echo ""
    fi
}

log_section() {
    local message=$1
    log_to_file "SECTION" "$message"
    if type print_section &>/dev/null; then
        print_section "$message"
    else
        echo ""
        echo ">>> $message"
        echo ""
    fi
}

# Log command execution
log_command() {
    local cmd=$1
    log_to_file "COMMAND" "$cmd"
}

# Log command output
log_output() {
    local output=$1
    log_to_file "OUTPUT" "$output"
}

# Get log file path
get_log_file() {
    echo "$LOG_FILE"
}

# Export log to a specific location
export_log() {
    local destination=$1
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "$destination"
        log_success "Log exported to: $destination"
    else
        log_error "Log file not found: $LOG_FILE"
        return 1
    fi
}
