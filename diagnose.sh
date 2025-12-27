#!/usr/bin/env bash
# Network Diagnostics Master Script
# Runs all layer checks in sequence to diagnose network connectivity
#
# Usage: sudo ./diagnose.sh [DESTINATION_IP] [PORT]
#
# Exit Codes:
#   0   - All checks passed
#   1   - Permission denied
#   10+ - Check failed at specific layer (see individual scripts)

set -euo pipefail

# -------- Configuration --------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CHECKS_DIR="${SCRIPT_DIR}/scripts/checks"
readonly LOG_PREFIX="[DIAG]"

# ANSI color codes
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# -------- Helpers --------

log() {
    printf '%s %s\n' "$LOG_PREFIX" "$1"
}

log_header() {
    printf '\n%b=== %s ===%b\n' "$COLOR_BLUE" "$1" "$COLOR_RESET"
}

log_success() {
    printf '%b✓ %s%b\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

log_failure() {
    printf '%b✗ %s%b\n' "$COLOR_RED" "$1" "$COLOR_RESET"
}

log_warning() {
    printf '%b⚠ %s%b\n' "$COLOR_YELLOW" "$1" "$COLOR_RESET"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_failure "This script must be run as root"
        exit 1
    fi
}

# -------- Layer Runners --------

run_check() {
    local script_name="$1"
    local script_path="${CHECKS_DIR}/${script_name}"
    shift  # Remove script_name from arguments
    local args=("$@")
    
    if [[ ! -f "$script_path" ]]; then
        log_warning "${script_name} not found, skipping"
        return 0
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log_warning "${script_name} not executable, skipping"
        return 0
    fi
    
    # Run the check and capture output and exit code
    local output exit_code
    set +e  # Temporarily disable exit on error
    output=$("$script_path" "${args[@]}" 2>&1)
    exit_code=$?
    set -e
    
    echo "$output"
    return $exit_code
}

# -------- Main Diagnostic Flow --------

main() {
    local destination="${1:-8.8.8.8}"
    local port="${2:-80}"
    local failed_checks=()
    local total_checks=0
    local passed_checks=0
    
    require_root
    
    log_header "Network Diagnostics for $destination${port:+:$port}"
    log "Target: $destination"
    [[ -n "$port" ]] && log "Port: $port"
    echo ""
    
    # Layer 2: Link Layer
    log_header "Layer 2: Link Layer Diagnostics"
    total_checks=$((total_checks + 1))
    if run_check "l2_link.sh" "$destination"; then
        log_success "L2 checks passed"
        passed_checks=$((passed_checks + 1))
    else
        log_failure "L2 checks failed"
        failed_checks+=("L2")
    fi
    
    # Layer 3: Network Layer
    log_header "Layer 3: Network Layer Diagnostics"
    total_checks=$((total_checks + 1))
    if run_check "l3_network.sh" "$destination"; then
        log_success "L3 checks passed"
        passed_checks=$((passed_checks + 1))
    else
        log_failure "L3 checks failed"
        failed_checks+=("L3")
    fi
    
    # Layer 4: Transport Layer
    log_header "Layer 4: Transport Layer Diagnostics"
    total_checks=$((total_checks + 1))
    if run_check "l4_transport.sh" "$destination" "$port" "tcp"; then
        log_success "L4 checks passed"
        passed_checks=$((passed_checks + 1))
    else
        log_failure "L4 checks failed"
        failed_checks+=("L4")
    fi
    
    # Firewall Layer
    log_header "Firewall Rules Diagnostics"
    total_checks=$((total_checks + 1))
    if run_check "firewall.sh" "$destination" "$port"; then
        log_success "Firewall checks passed"
        passed_checks=$((passed_checks + 1))
    else
        local fw_exit=$?
        if [[ $fw_exit -eq 42 ]]; then
            log_warning "No firewall detected (pass)"
            passed_checks=$((passed_checks + 1))
        else
            log_failure "Firewall checks failed"
            failed_checks+=("Firewall")
        fi
    fi
    
    # Summary
    log_header "Diagnostic Summary"
    echo ""
    printf "Checks passed: %d/%d\n" "$passed_checks" "$total_checks"
    
    if [[ ${#failed_checks[@]} -eq 0 ]]; then
        log_success "All network layers permit communication to $destination${port:+:$port}"
        echo ""
        log "Network stack is healthy ✓"
        exit 0
    else
        echo ""
        log_failure "Failed layers: ${failed_checks[*]}"
        echo ""
        log "Network communication is blocked at one or more layers"
        log "Review the output above for specific issues"
        exit 1
    fi
}

# Run main with all script arguments
main "$@"