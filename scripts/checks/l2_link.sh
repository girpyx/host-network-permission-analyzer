#!/usr/bin/env bash
# Layer 2 Link Diagnostics
# Determines whether frame-level communication is permitted
# Interface selection is derived from kernel routing intent

set -euo pipefail

TARGET="${1:-8.8.8.8}"

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

# -------- interface selection --------

detect_interface() {
    iface=$(ip route get "$TARGET" 2>/dev/null \
        | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' \
        | head -n1)

    [[ -z "$iface" ]] && fail "no routed interface found for $TARGET" 11
    [[ "$iface" == "lo" ]] && fail "routing resolved to loopback (lo), external L2 not applicable" 11

    log "routed interface: $iface"
}

# -------- checks --------

check_rfkill() {
    if command -v rfkill >/dev/null 2>&1; then
        if rfkill list | grep -qE "Soft blocked: yes|Hard blocked: yes"; then
            fail "rfkill blocking detected" 10
        fi
        log "rfkill: OK"
    else
        log "rfkill: not installed (skipped)"
    fi
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
            fail "wireless interface $iface not associated" 13
        fi
        log "wifi association: OK"
    else
        log "interface $iface is not wireless (skipped)"
    fi
}

check_neighbor_reachability() {
    gw=$(ip route get "$TARGET" | awk '/via/ {print $3}' | head -n1 || true)

    [[ -z "$gw" ]] && {
        log "no gateway (direct L2 reachability assumed)"
        return 0
    }

    ip neigh show "$gw" dev "$iface" \
        | grep -qE "REACHABLE|STALE|DELAY" \
        || fail "neighbor $gw unreachable at L2" 14

    log "neighbor reachability: OK ($gw)"
}

# -------- main --------

require_root
detect_interface
check_rfkill
check_link_state
check_wifi_association
check_neighbor_reachability

log "L2 communication permitted on $iface"
exit 0
