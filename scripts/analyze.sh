#!/usr/bin/env bash
# Host Network Permission Analyzer
# Orchestrates L2 -> L3 diagnostics in strict order

set -euo pipefail

DESTINATION="${1:-8.8.8.8}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="$BASE_DIR/checks"

log() {
    printf '[ANALYZE] %s\n' "$1"
}

run_check() {
    local name="$1"
    shift

    log "running $name check"
    if "$@"; then
        log "$name check: PASS"
        return 0
    else
        rc=$?
        log "$name check: FAIL (exit code $rc)"
        exit "$rc"
    fi
}

# ---- main ----

log "starting host network permission analysis"
log "target destination: $DESTINATION"

run_check "L2" sudo "$CHECKS_DIR/l2_link.sh" "$DESTINATION"
run_check "L3" sudo "$CHECKS_DIR/l3_network.sh" "$DESTINATION"

log "analysis complete: L2 and L3 communication permitted"
exit 0
