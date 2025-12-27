#!/usr/bin/env bash
# Setup script for host-network-permission-analyzer
# Makes all scripts executable and checks dependencies

set -euo pipefail

readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

log() {
    printf '%b %s%b\n' "$LOG_PREFIX" "$1" "$COLOR_RESET" >&2  # Add >&2 to redirect to stderr
}

log_success() {
    printf '%b✓ %s%b\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

log_error() {
    printf '%b✗ %s%b\n' "$COLOR_RED" "$1" "$COLOR_RESET"
}

log_warning() {
    printf '%b⚠ %s%b\n' "$COLOR_YELLOW" "$1" "$COLOR_RESET"
}

log_info() {
    printf '%b→ %s%b\n' "$COLOR_BLUE" "$1" "$COLOR_RESET"
}

check_bash_version() {
    local bash_version
    bash_version=$(bash --version | head -n1 | awk '{print $4}' | cut -d. -f1)
    
    if [[ "$bash_version" -lt 4 ]]; then
        log_error "Bash 4.0 or later required (found version $bash_version)"
        return 1
    fi
    
    log_success "Bash version OK ($bash_version.x)"
}

make_executable() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_warning "File not found: $file"
        return 1
    fi
    
    chmod +x "$file"
    log_success "Made executable: $file"
}

check_command() {
    local cmd="$1"
    local optional="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$cmd installed"
        return 0
    else
        if [[ "$optional" == "optional" ]]; then
            log_warning "$cmd not installed (optional)"
        else
            log_error "$cmd not installed (required)"
        fi
        return 1
    fi
}

main() {
    echo ""
    log_info "Setting up Host Network Permission Analyzer..."
    echo ""
    
    # Check Bash version
    log_info "Checking Bash version..."
    check_bash_version || exit 1
    echo ""
    
    # Make scripts executable
    log_info "Making scripts executable..."
    make_executable "diagnose.sh"
    
    if [[ -d "scripts/checks" ]]; then
        for script in scripts/checks/*.sh; do
            if [[ -f "$script" ]]; then
                make_executable "$script"
            fi
        done
    else
        log_warning "scripts/checks directory not found"
    fi
    echo ""
    
    # Check required dependencies
    log_info "Checking required dependencies..."
    local missing_required=0
    
    check_command "ip" "required" || missing_required=$((missing_required + 1))
    echo ""
    
    # Check optional dependencies
    log_info "Checking optional dependencies..."
    check_command "iw" "optional"
    check_command "rfkill" "optional"
    check_command "nc" "optional"
    check_command "ping" "optional"
    check_command "ss" "optional"
    check_command "nft" "optional"
    check_command "iptables" "optional"
    echo ""
    
    # Installation suggestions
    if [[ $missing_required -gt 0 ]]; then
        log_error "Missing required dependencies!"
        echo ""
        log_info "On Ubuntu/Debian, install with:"
        echo "  sudo apt install iproute2"
        echo ""
        exit 1
    fi
    
    log_info "To install optional tools on Ubuntu/Debian:"
    echo "  sudo apt install wireless-tools rfkill netcat-openbsd iputils-ping"
    echo ""
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_warning "Setup complete, but scripts require root to run"
        log_info "Run diagnostics with: sudo ./diagnose.sh"
    else
        log_success "Setup complete! Scripts are ready to use."
        log_info "Run diagnostics with: ./diagnose.sh"
    fi
    
    echo ""
    log_success "Setup completed successfully!"
    echo ""
    log_info "Quick start:"
    echo "  sudo ./diagnose.sh 8.8.8.8 80"
    echo ""
    log_info "Individual layer checks:"
    echo "  sudo ./scripts/checks/l2_link.sh 8.8.8.8"
    echo "  sudo ./scripts/checks/l3_network.sh 8.8.8.8"
    echo "  sudo ./scripts/checks/l4_transport.sh 8.8.8.8 80"
    echo "  sudo ./scripts/checks/firewall.sh 8.8.8.8 80"
    echo ""
}

main "$@"