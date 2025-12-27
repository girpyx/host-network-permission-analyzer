Network Diagnostics Libraries
This directory contains shared libraries used across all diagnostic scripts.

Library Files
logging.sh
Centralized logging functions with color support and log levels.

Features:

Multiple log levels (DEBUG, INFO, WARN, ERROR, FAIL)
Color-coded output (automatically disabled for non-TTY)
Optional file logging
Consistent formatting across all scripts
Usage:

bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/logging.sh"

# Set log prefix for your script
LOG_PREFIX="[L2]"

# Basic logging
log_info "Starting check"
log_success "Check passed"
log_warn "Optional tool not found"
log_error "Check failed"

# Enable file logging
enable_file_logging "/var/log/network-diag.log"

# Set log level
set_log_level "debug"  # Shows all messages
LOG_LEVEL=$LOG_LEVEL_WARN  # Only warnings and above
exit_codes.sh
Centralized exit code definitions and descriptions.

Features:

Consistent exit codes across all scripts
Human-readable descriptions
Layer identification from exit codes
Exit code documentation functions
Exit Code Ranges:

0 - Success
1-9 - General errors
10-19 - Layer 2 errors
20-29 - Layer 3 errors
30-39 - Layer 4 errors
40-49 - Firewall errors
50-59 - DNS/Application errors
Usage:

bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/exit_codes.sh"

# Use named exit codes
exit "$EXIT_L2_NO_CARRIER"

# Get description
description=$(get_exit_code_description "$EXIT_L3_NO_IP_ADDRESS")
echo "Error: $description"

# Print full exit code info
print_exit_code_info "$exit_code"
utils.sh
Common utility functions for validation, network operations, and helpers.

Features:

Root permission checking
Command availability validation
IP and port validation
Network interface helpers
String manipulation
JSON output helpers
Retry logic
Progress indicators
Usage:

bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/utils.sh"

# Validation
require_root || exit 1
check_commands "ip" "ping" "nc" || exit 3

# Network helpers
iface=$(get_interface_for_target "8.8.8.8")
gateway=$(get_gateway_for_target "8.8.8.8")

if is_interface_up "$iface"; then
    echo "Interface is up"
fi

# IP validation
if is_valid_ip "192.168.1.1"; then
    echo "Valid IP"
fi

# Retry logic
if retry 3 2 ping -c 1 8.8.8.8; then
    echo "Ping succeeded after retries"
fi

# JSON output
json_key_value "status" "success"
Integration Example
Here's a complete example of using all libraries together:

bash
#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libraries
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/exit_codes.sh"
source "${LIB_DIR}/utils.sh"

# Configure
LOG_PREFIX="[MYCHECK]"

main() {
    local target="${1:-8.8.8.8}"
    
    # Validation
    require_root || exit "$EXIT_PERMISSION_DENIED"
    
    if ! is_valid_ip "$target"; then
        log_error "Invalid IP address: $target"
        exit "$EXIT_INVALID_ARGUMENTS"
    fi
    
    # Get network info
    local iface
    iface=$(get_interface_for_target "$target")
    readonly iface
    
    log_info "Using interface: $iface"
    
    # Check interface state
    if ! is_interface_up "$iface"; then
        log_error "Interface $iface is down"
        exit "$EXIT_L2_INTERFACE_DOWN"
    fi
    
    log_success "Check passed"
    exit "$EXIT_SUCCESS"
}

main "$@"
Benefits of Using Libraries
1. Consistency
All scripts use the same logging format, exit codes, and utility functions.

2. Maintainability
Fix a bug once in the library, all scripts benefit.

3. Readability
Scripts are cleaner and focus on their specific logic.

4. Extensibility
Easy to add new features (e.g., JSON output) to all scripts at once.

5. Testing
Libraries can be tested independently.

Adding New Functions
When adding new functions to libraries:

Document the function with comments
Follow naming conventions:
check_* for validation functions
get_* for retrieval functions
is_* for boolean checks
log_* for logging functions
Return values properly:
Use echo for string output
Use return codes for success/failure
Keep functions focused - one responsibility per function
Test thoroughly before committing
Library Dependencies
Required
Bash 4.0+
Standard GNU utilities (awk, grep, sed)
Optional
ip command (for network helpers)
date with -Iseconds support (for timestamps)
Version History
v1.0.0 (2024-12) - Initial library creation
logging.sh: Basic logging with colors
exit_codes.sh: Exit code definitions
utils.sh: Common utilities
Future Enhancements
Planned features for future versions:

 Structured logging (syslog integration)
 More comprehensive JSON output helpers
 Performance timing utilities
 Configuration file parsing
 Plugin system for custom checks
 Email/notification helpers
 Database logging support
