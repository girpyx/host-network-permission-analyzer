#!/usr/bin/env bash
# Firewall Rules Diagnostics
# Determines whether firewall rules permit network communication
#
# Usage: sudo ./firewall.sh [DESTINATION_IP] [PORT]
#
# Exit Codes:
#   0  - Firewall rules permit communication
#   1  - Permission denied (not root)
#   40 - Firewall explicitly blocks traffic
#   41 - Default policy is DROP/REJECT
#   42 - No firewall detected (informational)

set -euo pipefail

# -------- Configuration --------

readonly LOG_PREFIX="[FW]"

# -------- Helpers --------

log() {
    printf '%s %s\n' "$LOG_PREFIX" "$1"
}

fail() {
    local message="$1"
    local exit_code="$2"
    log "FAIL: $message"
    exit "$exit_code"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "must be run as root (CAP_NET_ADMIN required)" 1
    fi
}

# -------- Firewall Detection --------

detect_firewall_type() {
    local fw_type="none"
    
    if command -v nft >/dev/null 2>&1 && nft list tables 2>/dev/null | grep -q .; then
        fw_type="nftables"
    elif command -v iptables >/dev/null 2>&1 && iptables -L -n >/dev/null 2>&1; then
        fw_type="iptables"
    elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        fw_type="ufw"
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -q "running"; then
        fw_type="firewalld"
    fi
    
    echo "$fw_type"
}

# -------- Checks --------

check_iptables_rules() {
    local destination="$1"
    local port="$2"
    
    log "checking iptables rules"
    
    # Check OUTPUT chain (outbound traffic)
    local output_policy
    output_policy=$(iptables -L OUTPUT -n | head -n1 | awk '{print $4}' | tr -d '()')
    
    if [[ "$output_policy" == "DROP" || "$output_policy" == "REJECT" ]]; then
        log "WARNING: OUTPUT chain default policy is $output_policy"
        
        # Check if there's an explicit ACCEPT rule
        if ! iptables -L OUTPUT -n | grep -q "ACCEPT.*$destination"; then
            fail "OUTPUT chain blocks traffic to $destination (policy: $output_policy)" 41
        fi
    fi
    
    # Check INPUT chain (inbound traffic)
    local input_policy
    input_policy=$(iptables -L INPUT -n | head -n1 | awk '{print $4}' | tr -d '()')
    
    if [[ "$input_policy" == "DROP" || "$input_policy" == "REJECT" ]]; then
        log "WARNING: INPUT chain default policy is $input_policy"
    fi
    
    # Check for explicit DROP/REJECT rules
    if iptables -L -n | grep -E "DROP|REJECT" | grep -q "$destination"; then
        fail "explicit DROP/REJECT rule found for $destination" 40
    fi
    
    log "iptables: no blocking rules found"
}

check_nftables_rules() {
    local destination="$1"
    local port="$2"
    
    log "checking nftables rules"
    
    local ruleset
    ruleset=$(nft list ruleset 2>/dev/null || true)
    
    if [[ -z "$ruleset" ]]; then
        log "nftables: no rules configured"
        return 0
    fi
    
    # Check for drop/reject rules
    if echo "$ruleset" | grep -E "drop|reject" | grep -q "$destination"; then
        fail "nftables rule blocks traffic to $destination" 40
    fi
    
    # Check default policies
    if echo "$ruleset" | grep "policy drop" | grep -q "output"; then
        log "WARNING: nftables output policy is drop"
    fi
    
    log "nftables: no blocking rules found"
}

check_ufw_rules() {
    local destination="$1"
    local port="$2"
    
    log "checking ufw rules"
    
    local ufw_status
    ufw_status=$(ufw status verbose 2>/dev/null || true)
    
    # Check default outgoing policy
    if echo "$ufw_status" | grep "Default:" | grep -q "outgoing deny"; then
        log "WARNING: ufw default outgoing policy is deny"
    fi
    
    # Check for specific deny rules
    if echo "$ufw_status" | grep -i "deny" | grep -q "$port"; then
        fail "ufw denies traffic on port $port" 40
    fi
    
    log "ufw: no blocking rules found"
}

check_firewalld_rules() {
    local destination="$1"
    local port="$2"
    
    log "checking firewalld rules"
    
    # Get default zone
    local zone
    zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "public")
    
    log "default zone: $zone"
    
    # Check if port is allowed
    local port_info
    port_info=$(firewall-cmd --zone="$zone" --list-ports 2>/dev/null || true)
    
    if [[ -n "$port" ]] && ! echo "$port_info" | grep -q "$port"; then
        log "WARNING: port $port not explicitly allowed in zone $zone"
    fi
    
    # Check for rich rules that might block
    local rich_rules
    rich_rules=$(firewall-cmd --zone="$zone" --list-rich-rules 2>/dev/null || true)
    
    if echo "$rich_rules" | grep -i "reject\|drop" | grep -q "$destination"; then
        fail "firewalld rich rule blocks traffic to $destination" 40
    fi
    
    log "firewalld: no blocking rules found"
}

# -------- Main --------

main() {
    local destination="${1:-8.8.8.8}"
    local port="${2:-}"
    local fw_type
    
    require_root
    
    fw_type=$(detect_firewall_type)
    log "detected firewall: $fw_type"
    
    case "$fw_type" in
        iptables)
            check_iptables_rules "$destination" "$port"
            ;;
        nftables)
            check_nftables_rules "$destination" "$port"
            ;;
        ufw)
            check_ufw_rules "$destination" "$port"
            ;;
        firewalld)
            check_firewalld_rules "$destination" "$port"
            ;;
        none)
            log "no active firewall detected"
            exit 42
            ;;
    esac

    log "firewall permits communication to $destination"
    exit 0
}

# Run main with all script arguments
main "$@"