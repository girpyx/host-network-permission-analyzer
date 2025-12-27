#!/usr/bin/env bash
# Layer 3 Network Diagnostics
# Determines whether IP packet routing is permitted
#
# Usage: sudo ./l3_network.sh [DESTINATION_IP]
#
# Exit Codes:
#   0  - L3 communication permitted
#   1  - Permission denied (not root)
#   20 - No IP address assigned to interface
#   21 - No route to destination
#   22 - Gateway unreachable (ICMP)
#   23 - Destination unreachable (ICMP)

set -euo pipefail

# -------- Configuration --------

readonly LOG_PREFIX="[L3]"

# -------- Helpers --------

log() {
    printf '%s %s\n' "$LOG_PREFIX" "$1" >&2  # Add >&2 to redirect to stderr
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

# -------- Interface Selection --------

detect_interface() {
    local destination="$1"
    local iface
    
    iface=$(ip route get "$destination" 2>/dev/null \
        | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' \
        | head -n1)

    if [[ -z "$iface" ]]; then
        fail "no routed interface found for $destination" 21
    fi

    if [[ "$iface" == "lo" ]]; then
        fail "routing resolved to loopback (lo), external communication not applicable" 21
    fi

    log "routed interface: $iface"
    echo "$iface"  # Return via stdout
}

# -------- Checks --------

check_ip_address() {
    local iface="$1"
    local has_ipv4 has_ipv6
    
    has_ipv4=$(ip addr show "$iface" | grep -c "inet " || true)
    has_ipv6=$(ip addr show "$iface" | grep "inet6 " | grep -cv "fe80::" || true)
    
    if [[ "$has_ipv4" -eq 0 && "$has_ipv6" -eq 0 ]]; then
        fail "no IP address assigned to $iface (use 'dhclient $iface' or configure static IP)" 20
    fi
    
    [[ "$has_ipv4" -gt 0 ]] && log "IPv4 address present on $iface"
    [[ "$has_ipv6" -gt 0 ]] && log "IPv6 address present on $iface (global)"
}

check_route() {
    local destination="$1"
    local route_info
    
    route_info=$(ip route get "$destination" 2>/dev/null || true)

    if [[ -z "$route_info" ]]; then
        fail "no route to $destination (check routing table with 'ip route')" 21
    fi

    log "route exists: $route_info"
    echo "$route_info"  # Return for gateway extraction
}

extract_gateway() {
    local route_info="$1"
    local gw
    
    gw=$(echo "$route_info" | awk '/via/ {print $3}' | head -n1 || true)

    if [[ -z "$gw" ]]; then
        log "destination is directly reachable (no gateway)"
    else
        log "gateway detected: $gw"
    fi
    
    echo "$gw"  # Return gateway (may be empty)
}

check_gateway_reachability() {
    local gw="$1"
    
    # No gateway means direct connectivity
    [[ -z "$gw" ]] && return 0
    
    if ! command -v ping >/dev/null 2>&1; then
        log "ping not available, skipping gateway ICMP test"
        return 0
    fi
    
    if ! ping -c 1 -W 2 "$gw" >/dev/null 2>&1; then
        fail "gateway $gw unreachable via ICMP (check L2 connectivity or firewall)" 22
    fi

    log "gateway reachable via ICMP"
}

check_destination_reachability() {
    local destination="$1"
    
    if ! command -v ping >/dev/null 2>&1; then
        log "ping not available, skipping destination ICMP test"
        return 0
    fi
    
    if ! ping -c 1 -W 2 "$destination" >/dev/null 2>&1; then
        fail "destination $destination unreachable via ICMP (check remote firewall or routing)" 23
    fi

    log "destination reachable via ICMP"
}

# -------- Main --------

main() {
    local destination="${1:-8.8.8.8}"
    local iface route_info gw
    
    require_root
    
    iface=$(detect_interface "$destination")
    readonly iface
    
    check_ip_address "$iface"
    
    route_info=$(check_route "$destination")
    
    gw=$(extract_gateway "$route_info")
    readonly gw
    
    check_gateway_reachability "$gw"
    check_destination_reachability "$destination"

    log "L3 communication permitted to $destination"
    exit 0
}

# Run main with all script arguments
main "$@"