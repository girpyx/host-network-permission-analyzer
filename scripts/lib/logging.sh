#!/usr/bin/env bash
# Shared logging functions for network diagnostics
# Source this file in your scripts: source "$(dirname "$0")/../lib/logging.sh"

# ANSI color codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FAIL=4

# Default log level (can be overridden by setting LOG_LEVEL env var)
: "${LOG_LEVEL:=$LOG_LEVEL_INFO}"

# Optional log file (set LOG_FILE env var to enable file logging)
: "${LOG_FILE:=}"

# Log prefix (set by individual scripts, e.g., LOG_PREFIX="[L2]")
: "${LOG_PREFIX:=}"

# -------- Core Logging Functions --------

_log_message() {
    local level="$1"
    local color="$2"
    local symbol="$3"
    local message="$4"
    local timestamp
    
    # Skip if log level is below threshold
    [[ "$level" -lt "$LOG_LEVEL" ]] && return 0
    
    # Format message
    local formatted_message
    if [[ -n "$LOG_PREFIX" ]]; then
        formatted_message="${LOG_PREFIX} ${message}"
    else
        formatted_message="${message}"
    fi
    
    # Print to stdout with color
    if [[ -t 1 ]]; then
        # Terminal supports colors
        printf '%b%s %s%b\n' "$color" "$symbol" "$formatted_message" "$COLOR_RESET"
    else
        # No color support
        printf '%s %s\n' "$symbol" "$formatted_message"
    fi
    
    # Log to file if enabled
    if [[ -n "$LOG_FILE" ]]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        printf '[%s] %s %s\n' "$timestamp" "$symbol" "$formatted_message" >> "$LOG_FILE"
    fi
}

# -------- Public Logging Functions --------

log_debug() {
    _log_message "$LOG_LEVEL_DEBUG" "$COLOR_CYAN" "[DEBUG]" "$1"
}

log_info() {
    _log_message "$LOG_LEVEL_INFO" "$COLOR_BLUE" "[INFO]" "$1"
}

log() {
    # Alias for log_info for backward compatibility
    log_info "$1"
}

log_success() {
    _log_message "$LOG_LEVEL_INFO" "$COLOR_GREEN" "✓" "$1"
}

log_warn() {
    _log_message "$LOG_LEVEL_WARN" "$COLOR_YELLOW" "⚠" "$1"
}

log_warning() {
    # Alias for log_warn
    log_warn "$1"
}

log_error() {
    _log_message "$LOG_LEVEL_ERROR" "$COLOR_RED" "✗" "$1" >&2
}

log_fail() {
    _log_message "$LOG_LEVEL_FAIL" "$COLOR_RED" "[FAIL]" "$1" >&2
}

# -------- Helper Functions --------

log_header() {
    local message="$1"
    if [[ -t 1 ]]; then
        printf '\n%b=== %s ===%b\n' "$COLOR_BLUE" "$message" "$COLOR_RESET"
    else
        printf '\n=== %s ===\n' "$message"
    fi
}

log_separator() {
    printf '%s\n' "----------------------------------------"
}

# Set log level from string (for CLI arguments)
set_log_level() {
    local level="$1"
    case "$level" in
        debug|DEBUG)
            LOG_LEVEL=$LOG_LEVEL_DEBUG
            ;;
        info|INFO)
            LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
        warn|WARN|warning|WARNING)
            LOG_LEVEL=$LOG_LEVEL_WARN
            ;;
        error|ERROR)
            LOG_LEVEL=$LOG_LEVEL_ERROR
            ;;
        *)
            log_error "Unknown log level: $level"
            return 1
            ;;
    esac
}

# Enable file logging
enable_file_logging() {
    local log_file="$1"
    LOG_FILE="$log_file"
    
    # Create log directory if needed
    local log_dir
    log_dir=$(dirname "$log_file")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            log_error "Failed to create log directory: $log_dir"
            return 1
        }
    fi
    
    log_debug "File logging enabled: $LOG_FILE"
}

# Disable colors (useful for piping output)
disable_colors() {
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_CYAN=''
    COLOR_RESET=''
}