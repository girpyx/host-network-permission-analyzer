#!/usr/bin/env bash
# Layer 3 Network Diagnostics
# Determines whether IP packet routing is permitted

set -euo pipefail

DESTINATION="${1:-8.8.8.8}"

# -------- helpers --------

log() {
    printf '[L3] %s\n' "$1"
}

fail() {
    log "FAIL: $1"
    exit "$2"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "must be run as root (CAP_NET_ADMIN required)" 1
    fi
}

# -------- checks --------

detect_interface() {
    local target="${1:-8.8.8.8}"

    iface=$(ip route get "$target" 2>/dev/null | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -n1)

    [[ -z "$iface" ]] && fail "no routed interface found for $target" 21

    [[ "$iface" == "lo" ]] && fail "routing resolved to loopback (lo), external communication not applicable" 21

    log "routed interface: $iface"
}


check_ip_address() {
    ip addr show "$iface" | grep -q "inet " \
        || fail "no IPv4 address assigned to $iface" 20

    log "IP address present on $iface"
}

check_route() {
    route_info=$(ip route get "$DESTINATION" 2>/dev/null || true)

    [[ -z "$route_info" ]] && fail "no route to $DESTINATION" 21

    log "route exists: $route_info"
}

extract_gateway() {
    gw=$(echo "$route_info" | awk '/via/ {print $3}' | head -n1 || true)

    if [[ -z "$gw" ]]; then
        log "destination is directly reachable (no gateway)"
    else
        log "gateway detected: $gw"
    fi
}

check_gateway_reachability() {
    [[ -z "${gw:-}" ]] && return 0

    ping -c 1 -W 1 "$gw" >/dev/null 2>&1 \
        || fail "gateway $gw unreachable" 22

    log "gateway reachable"
}

check_destination_reachability() {
    ping -c 1 -W 1 "$DESTINATION" >/dev/null 2>&1 \
        || fail "destination $DESTINATION unreachable" 23

    log "destination reachable"
}

# -------- main --------

require_root
detect_interface
check_ip_address
check_route
extract_gateway
check_gateway_reachability
check_destination_reachability

log "L3 communication permitted to $DESTINATION"
exit 0
