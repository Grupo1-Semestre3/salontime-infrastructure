#!/bin/bash

# Color definitions for terminal output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'

# Print colored message functions
print_red() {
    echo -e "${RED}$1${NC}"
}

print_green() {
    echo -e "${GREEN}$1${NC}"
}

print_yellow() {
    echo -e "${YELLOW}$1${NC}"
}

print_blue() {
    echo -e "${BLUE}$1${NC}"
}

print_magenta() {
    echo -e "${MAGENTA}$1${NC}"
}

print_cyan() {
    echo -e "${CYAN}$1${NC}"
}

print_bold() {
    echo -e "${BOLD}$1${NC}"
}

# Header and section functions
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BOLD}${WHITE}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}>>> $1${NC}"
    echo ""
}

print_subsection() {
    echo -e "${MAGENTA}  → $1${NC}"
}

# Status functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Progress bar function
print_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "]${NC} ${percent}%% - ${message}"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Spinner function for long operations
show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r${CYAN}${spin:$i:1}${NC} ${message}"
        sleep 0.1
    done
    printf "\r"
}

# Box drawing for important messages
print_box() {
    local message=$1
    local length=${#message}
    local line=$(printf "%${length}s" | tr ' ' '─')
    
    echo -e "${CYAN}┌─${line}─┐${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}${message}${NC} ${CYAN}│${NC}"
    echo -e "${CYAN}└─${line}─┘${NC}"
}
