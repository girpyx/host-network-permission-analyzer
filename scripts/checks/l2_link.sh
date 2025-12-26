#!/usr/bin/env bash
# Layer 2 Link Diagnostics
# Determines whether frame-level communication is permitted

set -euo pipefail

# -------- helpers --------

log() {
    printf '[L2] %s\n' "$1"
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

check_rfkill() {
    if command -v rfkill >/dev/null 2>&1; then
        if rfkill list | grep -q "Soft blocked: yes\|Hard blocked: yes"; then
            fail "rfkill blocking detected" 10
        fi
        log "rfkill: OK"
    else
        log "rfkill: tool not present (skipped)"
    fi
}

detect_interface() {
    iface=$(ip -o link show up | awk -F': ' '{print $2}' | head -n1 || true)

    [[ -z "$iface" ]] && fail "no active network interface found" 11

    log "interface detected: $iface"
}

check_link_state() {
    state=$(ip link show "$iface")

    echo "$state" | grep -q "UP" || fail "interface $iface is DOWN" 11
    echo "$state" | grep -q "LOWER_UP" || fail "no carrier on $iface" 12

    log "interface state: UP with carrier"
}

check_wifi_association() {
    if iw dev "$iface" info >/dev/null 2>&1; then
        if ! iw dev "$iface" link | grep -q "Connected to"; then
            fail "wireless interface not associated" 13
        fi
        log "wifi association: OK"
    else
        log "interface is not wireless (skipped)"
    fi
}

check_neighbor_reachability() {
    gw=$(ip route show default 0.0.0.0/0 | awk '{print $3}' | head -n1 || true)

    [[ -z "$gw" ]] && fail "no default gateway found" 14

    ip neigh show "$gw" dev "$iface" | grep -q "REACHABLE\|STALE\|DELAY" \
        || fail "gateway neighbor unreachable at L2" 14

    log "neighbor reachability: OK ($gw)"
}

# -------- main --------

require_root
check_rfkill
detect_interface
check_link_state
check_wifi_association
check_neighbor_reachability

log "L2 communication permitted"
exit 0
