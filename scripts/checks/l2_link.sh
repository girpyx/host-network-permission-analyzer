#!/usr/bin/env bash
# Layer 2 Link Diagnostics - Complete Fixed Version
# Determines whether frame-level communication is permitted
#
# Usage: sudo ./l2_link.sh [TARGET_IP]
#
# Exit Codes:
#   0  - L2 communication permitted
#   1  - Permission denied (not root)
#   10 - RF kill blocking detected
#   11 - No route or interface DOWN
#   12 - No carrier (cable unplugged/adapter disabled)
#   13 - WiFi not associated to access point
#   14 - Gateway unreachable at L2

set -uo pipefail

# -------- Configuration --------

readonly LOG_PREFIX="[L2]"

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

# -------- Helper Functions --------

is_wireless_interface() {
    local iface="$1"
    [[ -d "/sys/class/net/$iface/wireless" ]]
}

# -------- Interface Selection --------

detect_interface() {
    local target="$1"
    local iface
    
    iface=$(ip route get "$target" 2>/dev/null \
        | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' \
        | head -n1)

    if [[ -z "$iface" ]]; then
        fail "no routed interface found for $target" 11
    fi
    
    if [[ "$iface" == "lo" ]]; then
        fail "routing resolved to loopback (lo), external L2 not applicable" 11
    fi

    echo "$iface"
}

# -------- Checks --------

check_rfkill() {
    local iface="$1"
    
    # Skip rfkill check for non-wireless interfaces
    if ! is_wireless_interface "$iface"; then
        log "rfkill: not applicable (interface is not wireless)"
        return 0
    fi
    
    if ! command -v rfkill >/dev/null 2>&1; then
        log "rfkill: not installed (skipped)"
        return 0
    fi
    
    if rfkill list | grep -qE "Soft blocked: yes|Hard blocked: yes"; then
        fail "rfkill blocking detected (use 'rfkill unblock all')" 10
    fi
    
    log "rfkill: OK"
}

check_link_state() {
    local iface="$1"
    local state
    
    state=$(ip link show "$iface" 2>/dev/null)

    if ! echo "$state" | grep -q "UP"; then
        fail "interface $iface is DOWN (use 'ip link set $iface up')" 11
    fi
    
    if ! echo "$state" | grep -q "LOWER_UP"; then
        fail "no carrier on $iface (cable unplugged or adapter disabled?)" 12
    fi

    log "interface state: UP with carrier"
}

check_wifi_association() {
    local iface="$1"
    
    if ! command -v iw >/dev/null 2>&1; then
        log "iw: not installed, skipping WiFi checks"
        return 0
    fi
    
    # Check if interface is wireless
    if ! is_wireless_interface "$iface"; then
        log "interface $iface is not wireless (skipped)"
        return 0
    fi
    
    if ! iw dev "$iface" link | grep -q "Connected to"; then
        fail "wireless interface $iface not associated to access point" 13
    fi
    
    log "wifi association: OK"
}

check_neighbor_reachability() {
    local iface="$1"
    local target="$2"
    local gw
    local neighbor_state
    
    gw=$(ip route get "$target" 2>/dev/null | awk '/via/ {print $3}' | head -n1 || true)

    if [[ -z "$gw" ]]; then
        log "no gateway (direct L2 reachability assumed)"
        return 0
    fi

    neighbor_state=$(ip neigh show "$gw" dev "$iface" 2>/dev/null || echo "NONE")
    
    if ! echo "$neighbor_state" | grep -qE "REACHABLE|STALE|DELAY"; then
        fail "neighbor $gw unreachable at L2 (state: ${neighbor_state})" 14
    fi

    log "neighbor reachability: OK ($gw)"
}

# -------- Main --------

main() {
    local target="${1:-8.8.8.8}"
    local iface
    
    require_root
    
    iface=$(detect_interface "$target")
    readonly iface
    log "routed interface: $iface"
    
    check_rfkill "$iface"
    check_link_state "$iface"
    check_wifi_association "$iface"
    check_neighbor_reachability "$iface" "$target"

    log "L2 communication permitted on $iface"
    exit 0
}

# Run main with all script arguments
main "$@"