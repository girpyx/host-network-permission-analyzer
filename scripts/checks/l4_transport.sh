#!/usr/bin/env bash
# Layer 4 Transport Diagnostics
# Determines whether TCP/UDP port connectivity is permitted
#
# Usage: sudo ./l4_transport.sh [DESTINATION_IP] [PORT] [PROTOCOL]
#
# Exit Codes:
#   0  - L4 communication permitted
#   1  - Permission denied (not root)
#   30 - Port closed or connection refused
#   31 - Connection timeout
#   32 - Required tools not available

set -euo pipefail

# -------- Configuration --------

readonly LOG_PREFIX="[L4]"
readonly DEFAULT_PORT="80"
readonly DEFAULT_PROTOCOL="tcp"

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

check_required_tools() {
    local missing_tools=()
    
    if ! command -v nc >/dev/null 2>&1 && ! command -v timeout >/dev/null 2>&1; then
        missing_tools+=("netcat or timeout")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        fail "required tools not available: ${missing_tools[*]} (install netcat-openbsd)" 32
    fi
}

# -------- Checks --------

check_tcp_connectivity() {
    local destination="$1"
    local port="$2"
    
    log "testing TCP connection to $destination:$port"
    
    # Try netcat first (more common)
    if command -v nc >/dev/null 2>&1; then
        if timeout 2 nc -zv "$destination" "$port" >/dev/null 2>&1; then
            log "TCP port $port open on $destination"
            return 0
        fi
    # Fallback to bash built-in
    elif timeout 2 bash -c "exec 3<>/dev/tcp/$destination/$port" 2>/dev/null; then
        exec 3>&-  # Close file descriptor
        log "TCP port $port open on $destination"
        return 0
    fi
    
    fail "TCP port $port closed or unreachable on $destination (connection refused/timeout)" 30
}

check_udp_connectivity() {
    local destination="$1"
    local port="$2"
    
    log "testing UDP connection to $destination:$port"
    
    if ! command -v nc >/dev/null 2>&1; then
        log "netcat not available, cannot reliably test UDP (skipping)"
        return 0
    fi
    
    # UDP is tricky - we can send but can't reliably know if port is open
    # This just checks if we can send a packet
    if timeout 2 nc -zuv "$destination" "$port" >/dev/null 2>&1; then
        log "UDP packet sent to $destination:$port (response uncertain)"
    else
        log "UDP send to $destination:$port may have failed (unreliable without response)"
    fi
}

check_local_port_binding() {
    local port="$1"
    local protocol="$2"
    
    log "checking if local services are listening on port $port"
    
    if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
        log "ss/netstat not available, skipping local port check"
        return 0
    fi
    
    local listening
    if command -v ss >/dev/null 2>&1; then
        listening=$(ss -ln "$protocol" | grep ":$port " || true)
    else
        listening=$(netstat -ln | grep "$protocol.*:$port " || true)
    fi
    
    if [[ -n "$listening" ]]; then
        log "local service listening on $protocol/$port"
    else
        log "no local service bound to $protocol/$port"
    fi
}

# -------- Main --------

main() {
    local destination="${1:-8.8.8.8}"
    local port="${2:-$DEFAULT_PORT}"
    local protocol="${3:-$DEFAULT_PROTOCOL}"
    
    require_root
    check_required_tools
    
    protocol=$(echo "$protocol" | tr '[:upper:]' '[:lower:]')
    
    case "$protocol" in
        tcp)
            check_tcp_connectivity "$destination" "$port"
            ;;
        udp)
            check_udp_connectivity "$destination" "$port"
            ;;
        *)
            fail "unsupported protocol: $protocol (use 'tcp' or 'udp')" 1
            ;;
    esac
    
    check_local_port_binding "$port" "$protocol"

    log "L4 communication permitted to $destination:$port ($protocol)"
    exit 0
}

# Run main with all script arguments
main "$@"