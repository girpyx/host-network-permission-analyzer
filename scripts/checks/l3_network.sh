#!/usr/bin/env bash
# Layer 3 Network Diagnostics - Improved Version
# Captures ALL diagnostic data before making pass/fail decisions
#
# Usage: sudo ./l3_network.sh [DESTINATION_IP] [--verbose]

# DO NOT use set -e - we want to capture all failures
set -uo pipefail

# -------- Configuration --------

readonly LOG_PREFIX="[L3]"
VERBOSE=false

# -------- State Tracking --------

declare -A L3_STATE=(
    [destination]=""
    [interface]=""
    [ipv4_addresses]=""
    [ipv6_addresses]=""
    [routing_table]=""
    [default_gateway]=""
    [specific_route]=""
    [gateway]=""
    [gateway_arp_entry]=""
    [gateway_ping_result]=""
    [destination_ping_result]=""
)

declare -A L3_ISSUES=()
declare -i L3_ERROR_COUNT=0
declare -i L3_WARNING_COUNT=0

# -------- Exit Codes --------

readonly EXIT_SUCCESS=0
readonly EXIT_PERMISSION_DENIED=1
readonly EXIT_L3_NO_IPV4=20
readonly EXIT_L3_NO_IPV6=21
readonly EXIT_L3_NO_ROUTE_DEFAULT=22
readonly EXIT_L3_NO_ROUTE_SPECIFIC=23
readonly EXIT_L3_GATEWAY_NO_ARP=24
readonly EXIT_L3_GATEWAY_NO_PING=25
readonly EXIT_L3_DESTINATION_NO_PING=26

# -------- Logging --------

log() {
    printf '%s %s\n' "$LOG_PREFIX" "$1"
}

log_verbose() {
    [[ "$VERBOSE" == true ]] && log "$1"
}

log_error() {
    printf '%s ERROR: %s\n' "$LOG_PREFIX" "$1" >&2
}

# -------- Validation --------

require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "must be run as root (CAP_NET_ADMIN required)"
        exit "$EXIT_PERMISSION_DENIED"
    fi
}

# -------- Interface Discovery --------

detect_interface() {
    local destination="$1"
    local iface
    
    log_verbose "Detecting interface for route to $destination"
    
    iface=$(ip route get "$destination" 2>/dev/null \
        | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' \
        | head -n1)

    if [[ -z "$iface" ]]; then
        L3_ISSUES[interface]="no_route_found"
        ((L3_ERROR_COUNT++))
        L3_STATE[interface]="none"
        return "$EXIT_L3_NO_ROUTE_SPECIFIC"
    fi
    
    if [[ "$iface" == "lo" ]]; then
        L3_ISSUES[interface]="loopback_routing"
        ((L3_ERROR_COUNT++))
        L3_STATE[interface]="lo"
        return "$EXIT_L3_NO_ROUTE_SPECIFIC"
    fi

    L3_STATE[interface]="$iface"
    log "routed interface: $iface"
    return 0
}

# -------- IP Address Checks --------

check_ip_addresses() {
    local iface="$1"
    local ipv4_addrs ipv6_addrs
    
    log_verbose "Checking IP address configuration on $iface"
    
    # Get all IPv4 addresses
    ipv4_addrs=$(ip -4 addr show "$iface" 2>/dev/null \
        | grep -oP 'inet \K[\d.]+/\d+' \
        | tr '\n' ' ')
    
    # Get all IPv6 addresses (exclude link-local)
    ipv6_addrs=$(ip -6 addr show "$iface" 2>/dev/null \
        | grep -v "fe80:" \
        | grep -oP 'inet6 \K[a-f0-9:]+/\d+' \
        | tr '\n' ' ')
    
    L3_STATE[ipv4_addresses]="${ipv4_addrs:-none}"
    L3_STATE[ipv6_addresses]="${ipv6_addrs:-none}"
    
    # Evaluate results
    if [[ -z "$ipv4_addrs" && -z "$ipv6_addrs" ]]; then
        L3_ISSUES[ip_config]="no_ip_addresses"
        ((L3_ERROR_COUNT++))
        log_error "No IP address assigned to $iface"
        return "$EXIT_L3_NO_IPV4"
    fi
    
    if [[ -n "$ipv4_addrs" ]]; then
        log "IPv4 address(es): $ipv4_addrs"
    else
        L3_ISSUES[ipv4]="no_ipv4"
        ((L3_WARNING_COUNT++))
        log "No IPv4 address (IPv6 only)"
    fi
    
    if [[ -n "$ipv6_addrs" ]]; then
        log "IPv6 address(es): $ipv6_addrs"
    fi
    
    return 0
}

# -------- Routing Checks --------

check_routing() {
    local destination="$1"
    local route_info
    
    log_verbose "Checking routing configuration"
    
    # Capture full routing table
    L3_STATE[routing_table]=$(ip route show 2>/dev/null)
    
    # Get default gateway
    local default_gw
    default_gw=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
    L3_STATE[default_gateway]="${default_gw:-none}"
    
    if [[ -z "$default_gw" ]]; then
        L3_ISSUES[routing]="no_default_gateway"
        ((L3_WARNING_COUNT++))
        log "Warning: No default gateway configured"
    else
        log_verbose "Default gateway: $default_gw"
    fi
    
    # Get specific route to destination
    route_info=$(ip route get "$destination" 2>/dev/null || true)
    L3_STATE[specific_route]="${route_info:-none}"
    
    if [[ -z "$route_info" ]]; then
        L3_ISSUES[routing]="no_route_to_dest"
        ((L3_ERROR_COUNT++))
        log_error "No route to $destination"
        return "$EXIT_L3_NO_ROUTE_SPECIFIC"
    fi
    
    log "Route: $route_info"
    
    # Extract gateway from specific route
    local gw
    gw=$(echo "$route_info" | awk '/via/ {print $3}' | head -n1)
    L3_STATE[gateway]="${gw:-direct}"
    
    if [[ -z "$gw" ]]; then
        log "Destination is directly reachable (no gateway)"
    else
        log "Gateway: $gw"
    fi
    
    return 0
}

# -------- Gateway Tests --------

test_gateway_reachability() {
    local gw="$1"
    
    # FIX: Don't check anything if no gateway
    if [[ -z "$gw" || "$gw" == "direct" ]]; then
        log "No gateway (destination directly reachable)"
        return 0
    fi
    
    log_verbose "Testing gateway reachability"
    
    # Check ARP/NDP table
    local neigh_entry
    neigh_entry=$(ip neigh show "$gw" 2>/dev/null | head -n1)
    L3_STATE[gateway_arp_entry]="${neigh_entry:-none}"
    
    if [[ -z "$neigh_entry" ]]; then
        L3_ISSUES[gateway_l2]="no_neighbor_entry"
        ((L3_WARNING_COUNT++))
        log "Warning: No ARP/NDP entry for gateway $gw"
    else
        local neigh_state
        neigh_state=$(echo "$neigh_entry" | awk '{print $NF}')
        log_verbose "Gateway neighbor state: $neigh_state"
        
        if [[ ! "$neigh_state" =~ REACHABLE|STALE|DELAY ]]; then
            L3_ISSUES[gateway_l2]="neighbor_failed"
            ((L3_WARNING_COUNT++))
            log "Warning: Gateway neighbor state is $neigh_state"
        fi
    fi
    
    # ICMP ping test (3 attempts)
    if command -v ping >/dev/null 2>&1; then
        local ping_result
        ping_result=$(ping -c 3 -W 2 -i 0.5 "$gw" 2>&1 || true)
        L3_STATE[gateway_ping_result]="$ping_result"
        
        if echo "$ping_result" | grep -q "0 received"; then
            L3_ISSUES[gateway_l3]="ping_failed"
            ((L3_ERROR_COUNT++))
            log_error "Gateway $gw unreachable (ICMP timeout)"
            return "$EXIT_L3_GATEWAY_NO_PING"
        else
            local packet_loss
            packet_loss=$(echo "$ping_result" | grep -oP '\d+% packet loss' | grep -oP '\d+')
            log "Gateway reachable (${packet_loss:-0}% packet loss)"
        fi
    else
        log "ping not available, skipping gateway ICMP test"
    fi
    
    return 0
}

# -------- Destination Tests --------

test_destination_reachability() {
    local destination="$1"
    
    log_verbose "Testing destination reachability"
    
    # ICMP ping test (3 attempts)
    if command -v ping >/dev/null 2>&1; then
        local ping_result
        ping_result=$(ping -c 3 -W 2 -i 0.5 "$destination" 2>&1 || true)
        L3_STATE[destination_ping_result]="$ping_result"
        
        if echo "$ping_result" | grep -q "0 received"; then
            L3_ISSUES[destination]="ping_failed"
            ((L3_ERROR_COUNT++))
            log_error "Destination $destination unreachable (ICMP timeout)"
            return "$EXIT_L3_DESTINATION_NO_PING"
        else
            # FIX: Better parsing
            local packet_loss rtt
            packet_loss=$(echo "$ping_result" | grep -oP '\d+(?=% packet loss)' | head -n1)
            rtt=$(echo "$ping_result" | grep -oP 'min/avg/max[^=]+=\s*[\d.]+/([\d.]+)' | grep -oP '(?<=/)[^/]+(?=/)' | head -n1)
            
            # Default to 0 if parsing fails
            packet_loss="${packet_loss:-0}"
            rtt="${rtt:-unknown}"
            
            log "Destination reachable (${packet_loss}% loss, ${rtt}ms avg)"
        fi
    else
        log "ping not available, skipping destination ICMP test"
    fi
    
    return 0
}

# -------- Report Generation --------

generate_report() {
    local final_exit_code="$1"
    
    echo ""
    echo "=== Layer 3 Diagnostic Report ==="
    echo ""
    echo "Target: ${L3_STATE[destination]}"
    echo "Interface: ${L3_STATE[interface]}"
    echo ""
    
    if [[ "$VERBOSE" == true ]]; then
        echo "IP Configuration:"
        echo "  IPv4: ${L3_STATE[ipv4_addresses]}"
        echo "  IPv6: ${L3_STATE[ipv6_addresses]}"
        echo ""
        echo "Routing:"
        echo "  Default Gateway: ${L3_STATE[default_gateway]}"
        echo "  Route to Target: ${L3_STATE[specific_route]}"
        echo ""
        
        if [[ "${L3_STATE[gateway]}" != "direct" && -n "${L3_STATE[gateway]}" ]]; then
            echo "Gateway Tests:"
            echo "  Address: ${L3_STATE[gateway]}"
            echo "  ARP Entry: ${L3_STATE[gateway_arp_entry]}"
            [[ -n "${L3_STATE[gateway_ping_result]}" ]] && echo "  Ping: OK"
            echo ""
        fi
    fi
    
    echo "Status: $L3_ERROR_COUNT error(s), $L3_WARNING_COUNT warning(s)"
    echo ""
    
    if [[ $L3_ERROR_COUNT -gt 0 ]]; then
        echo "Issues Found:"
        for issue in "${!L3_ISSUES[@]}"; do
            echo "  ✗ $issue: ${L3_ISSUES[$issue]}"
            provide_recommendation "$issue" "${L3_ISSUES[$issue]}"
        done
        echo ""
    fi
    
    if [[ $final_exit_code -eq 0 ]]; then
        log "L3 communication permitted to ${L3_STATE[destination]}"
    fi
}

provide_recommendation() {
    local issue="$1"
    local detail="$2"
    
    case "$issue" in
        interface)
            if [[ "$detail" == "no_route_found" ]]; then
                echo "    → No route to destination. Check:"
                echo "       - Interface is up: ip link show"
                echo "       - Routing table: ip route show"
                echo "       - Add default route: sudo ip route add default via <GATEWAY>"
            fi
            ;;
        ip_config)
            echo "    → No IP address configured. Try:"
            echo "       - DHCP: sudo dhclient ${L3_STATE[interface]}"
            echo "       - Static: sudo ip addr add <IP>/<MASK> dev ${L3_STATE[interface]}"
            ;;
        routing)
            if [[ "$detail" == "no_default_gateway" ]]; then
                echo "    → Configure default gateway:"
                echo "       sudo ip route add default via <GATEWAY_IP>"
            fi
            ;;
        gateway_l3)
            echo "    → Gateway not responding to ICMP:"
            echo "       - Verify gateway is online"
            echo "       - Check L2 connectivity first"
            echo "       - Gateway may block ICMP (check L4)"
            ;;
        destination)
            echo "    → Destination not responding to ICMP:"
            echo "       - Destination may be offline"
            echo "       - Firewall may block ICMP"
            echo "       - Try L4 test: nc -zv ${L3_STATE[destination]} 80"
            ;;
    esac
}

# -------- Main --------

main() {
    local destination="${1:-8.8.8.8}"
    local final_exit_code=0
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            *)
                destination="$1"
                shift
                ;;
        esac
    done
    
    L3_STATE[destination]="$destination"
    
    require_root
    
    # Run all checks - don't exit on first failure
    detect_interface "$destination" || final_exit_code=$?
    
    # Only continue if we have an interface
    if [[ "${L3_STATE[interface]}" != "none" && "${L3_STATE[interface]}" != "lo" ]]; then
        check_ip_addresses "${L3_STATE[interface]}" || true
        check_routing "$destination" || true
        test_gateway_reachability "${L3_STATE[gateway]}" || true
        test_destination_reachability "$destination" || true
    fi
    
    # Determine final exit code based on error count
    if [[ $L3_ERROR_COUNT -eq 0 ]]; then
        final_exit_code=0
    elif [[ -n "$final_exit_code" && $final_exit_code -ne 0 ]]; then
        # Keep the first error code
        :
    elif [[ -n "${L3_ISSUES[ip_config]}" ]]; then
        final_exit_code="$EXIT_L3_NO_IPV4"
    elif [[ -n "${L3_ISSUES[routing]}" ]]; then
        final_exit_code="$EXIT_L3_NO_ROUTE_SPECIFIC"
    elif [[ -n "${L3_ISSUES[gateway_l3]}" ]]; then
        final_exit_code="$EXIT_L3_GATEWAY_NO_PING"
    elif [[ -n "${L3_ISSUES[destination]}" ]]; then
        final_exit_code="$EXIT_L3_DESTINATION_NO_PING"
    else
        final_exit_code="$EXIT_L3_GATEWAY_NO_ARP"
    fi
    
    generate_report "$final_exit_code"
    exit "$final_exit_code"
}

main "$@"