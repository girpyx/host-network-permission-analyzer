#!/usr/bin/env bash
# Common utility functions for network diagnostics
# Source this file in your scripts: source "$(dirname "$0")/../lib/utils.sh"

# -------- Validation Functions --------

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root (requires CAP_NET_ADMIN)" >&2
        return 1
    fi
    return 0
}

check_command() {
    local cmd="$1"
    local required="${2:-optional}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        if [[ "$required" == "required" ]]; then
            echo "Error: Required command not found: $cmd" >&2
            return 1
        fi
        return 1
    fi
}

check_commands() {
    local missing_cmds=()
    local cmd
    
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        echo "Error: Missing required commands: ${missing_cmds[*]}" >&2
        return 1
    fi
    
    return 0
}

is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $regex ]]; then
        return 1
    fi
    
    # Check each octet is 0-255
    local IFS='.'
    local -a octets=($ip)
    local octet
    
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}

is_valid_port() {
    local port="$1"
    
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi
    
    return 0
}

# -------- Network Functions --------

get_interface_for_target() {
    local target="$1"
    local iface
    
    iface=$(ip route get "$target" 2>/dev/null \
        | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' \
        | head -n1)
    
    if [[ -z "$iface" ]]; then
        return 1
    fi
    
    echo "$iface"
}

get_gateway_for_target() {
    local target="$1"
    local gateway
    
    gateway=$(ip route get "$target" 2>/dev/null \
        | awk '/via/ {print $3}' \
        | head -n1)
    
    # May be empty for directly connected destinations
    echo "$gateway"
}

is_interface_up() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep -q "state UP"
}

has_carrier() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep -q "LOWER_UP"
}

is_wireless_interface() {
    local iface="$1"
    [[ -d "/sys/class/net/$iface/wireless" ]]
}

# -------- Error Handling --------

fail() {
    local message="$1"
    local exit_code="${2:-1}"
    
    echo "FAIL: $message" >&2
    exit "$exit_code"
}

die() {
    # Alias for fail with default exit code 1
    fail "$1" 1
}

# -------- String Manipulation --------

trim() {
    local var="$1"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# -------- File Operations --------

ensure_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            echo "Error: Failed to create directory: $dir" >&2
            return 1
        }
    fi
    
    return 0
}

# -------- Time Functions --------

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

get_timestamp_iso() {
    date -Iseconds
}

# -------- System Information --------

get_os_info() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "$NAME $VERSION"
    else
        uname -s
    fi
}

get_kernel_version() {
    uname -r
}

# -------- JSON Output Helpers --------

json_escape() {
    local str="$1"
    # Escape special JSON characters
    str="${str//\\/\\\\}"  # Backslash
    str="${str//\"/\\\"}"  # Quote
    str="${str//$'\n'/\\n}"  # Newline
    str="${str//$'\r'/\\r}"  # Carriage return
    str="${str//$'\t'/\\t}"  # Tab
    echo "$str"
}

json_key_value() {
    local key="$1"
    local value="$2"
    printf '"%s": "%s"' "$key" "$(json_escape "$value")"
}

# -------- Retry Logic --------

retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if "${command[@]}"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            sleep "$delay"
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# -------- Progress Indicators --------

show_spinner() {
    local pid="$1"
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf ' [%c]  ' "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf '\b\b\b\b\b\b'
    done
    printf '    \b\b\b\b'
}