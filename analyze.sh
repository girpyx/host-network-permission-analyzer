#!/usr/bin/env bash
# Advanced Network Analysis Tool
# Provides detailed analysis and recommendations based on diagnostic results
#
# Usage: sudo ./analyze.sh [OPTIONS] [DESTINATION] [PORT]
#
# Options:
#   -v, --verbose       Verbose output (shows all details)
#   -j, --json          Output in JSON format
#   -l, --log FILE      Enable logging to file
#   -q, --quiet         Quiet mode (errors only)
#   -h, --help          Show this help message

set -euo pipefail

# -------- Configuration --------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CHECKS_DIR="${SCRIPT_DIR}/scripts/checks"
readonly LIB_DIR="${SCRIPT_DIR}/scripts/lib"

# Source library files
# shellcheck source=scripts/lib/logging.sh
source "${LIB_DIR}/logging.sh"
# shellcheck source=scripts/lib/exit_codes.sh
source "${LIB_DIR}/exit_codes.sh"
# shellcheck source=scripts/lib/utils.sh
source "${LIB_DIR}/utils.sh"

# Analysis options
VERBOSE=false
JSON_OUTPUT=false
QUIET=false

# -------- Help Message --------

show_help() {
    cat << EOF
Advanced Network Analysis Tool

Usage: sudo ./analyze.sh [OPTIONS] [DESTINATION] [PORT]

Provides detailed network stack analysis with actionable recommendations.

Options:
  -v, --verbose       Show detailed analysis for each layer
  -j, --json          Output results in JSON format
  -l, --log FILE      Enable logging to specified file
  -q, --quiet         Only show errors and final summary
  -h, --help          Show this help message

Arguments:
  DESTINATION         Target IP address or hostname (default: 8.8.8.8)
  PORT               Target port number (default: 80)

Examples:
  # Basic analysis
  sudo ./analyze.sh 8.8.8.8 80

  # Verbose analysis with logging
  sudo ./analyze.sh -v -l /tmp/network-analysis.log 8.8.8.8 443

  # JSON output for automation
  sudo ./analyze.sh -j 192.168.1.1 22

Exit Codes:
  0   - All layers permit communication
  1   - One or more layers block communication
  2   - Invalid arguments
  3   - Required tools missing

EOF
}

# -------- Argument Parsing --------

parse_arguments() {
    local destination=""
    local port=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=true
                disable_colors
                shift
                ;;
            -l|--log)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --log requires a file path" >&2
                    exit 2
                fi
                enable_file_logging "$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                LOG_LEVEL=$LOG_LEVEL_ERROR
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 2
                ;;
            *)
                if [[ -z "$destination" ]]; then
                    destination="$1"
                elif [[ -z "$port" ]]; then
                    port="$1"
                else
                    echo "Error: Too many arguments" >&2
                    exit 2
                fi
                shift
                ;;
        esac
    done
    
    # Set defaults
    destination="${destination:-8.8.8.8}"
    port="${port:-80}"
    
    # Validate
    if ! is_valid_ip "$destination" && ! is_valid_hostname "$destination"; then
        echo "Error: Invalid destination: $destination" >&2
        exit 2
    fi
    
    if ! is_valid_port "$port"; then
        echo "Error: Invalid port: $port" >&2
        exit 2
    fi
    
    echo "$destination $port"
}

is_valid_hostname() {
    local hostname="$1"
    [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

# -------- Analysis Functions --------

run_layer_check() {
    local script_name="$1"
    local script_path="${CHECKS_DIR}/${script_name}"
    shift
    local args=("$@")
    
    if [[ ! -f "$script_path" ]]; then
        log_warn "${script_name} not found, skipping"
        return 0
    fi
    
    # Run check and capture output
    local output exit_code
    set +e
    output=$("$script_path" "${args[@]}" 2>&1)
    exit_code=$?
    set -e
    
    echo "$exit_code|$output"
}

analyze_result() {
    local layer="$1"
    local exit_code="$2"
    local output="$3"
    
    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi
    
    # Provide layer-specific recommendations
    case "$layer" in
        L2)
            analyze_l2_failure "$exit_code"
            ;;
        L3)
            analyze_l3_failure "$exit_code"
            ;;
        L4)
            analyze_l4_failure "$exit_code"
            ;;
        FW)
            analyze_fw_failure "$exit_code"
            ;;
    esac
}

analyze_l2_failure() {
    local exit_code="$1"
    
    log_header "Layer 2 Recommendations"
    
    case "$exit_code" in
        "$EXIT_L2_RFKILL_BLOCKED")
            echo "Issue: Wireless is blocked by rfkill"
            echo ""
            echo "Solutions:"
            echo "  1. Unblock wireless: sudo rfkill unblock all"
            echo "  2. Check for hardware switch on laptop"
            echo "  3. Check BIOS settings"
            ;;
        "$EXIT_L2_INTERFACE_DOWN")
            echo "Issue: Network interface is administratively down"
            echo ""
            echo "Solutions:"
            echo "  1. Bring interface up: sudo ip link set <interface> up"
            echo "  2. Check NetworkManager: nmcli device status"
            echo "  3. Check systemd-networkd: systemctl status systemd-networkd"
            ;;
        "$EXIT_L2_NO_CARRIER")
            echo "Issue: No physical carrier detected"
            echo ""
            echo "Solutions:"
            echo "  1. Check cable is plugged in (wired)"
            echo "  2. Try different cable"
            echo "  3. Check WiFi is enabled (wireless)"
            echo "  4. Move closer to access point (wireless)"
            ;;
        "$EXIT_L2_WIFI_NOT_ASSOCIATED")
            echo "Issue: WiFi interface not associated to access point"
            echo ""
            echo "Solutions:"
            echo "  1. Connect to WiFi: nmcli device wifi connect <SSID> password <PASSWORD>"
            echo "  2. Check available networks: nmcli device wifi list"
            echo "  3. Restart NetworkManager: sudo systemctl restart NetworkManager"
            ;;
        "$EXIT_L2_NEIGHBOR_UNREACHABLE")
            echo "Issue: Gateway unreachable at Layer 2 (ARP failure)"
            echo ""
            echo "Solutions:"
            echo "  1. Check gateway is online"
            echo "  2. Clear ARP cache: sudo ip neigh flush all"
            echo "  3. Verify you're on correct network segment"
            echo "  4. Check for MAC filtering on router"
            ;;
    esac
    echo ""
}

analyze_l3_failure() {
    local exit_code="$1"
    
    log_header "Layer 3 Recommendations"
    
    case "$exit_code" in
        "$EXIT_L3_NO_IP_ADDRESS")
            echo "Issue: No IP address assigned to interface"
            echo ""
            echo "Solutions:"
            echo "  1. Get IP via DHCP: sudo dhclient <interface>"
            echo "  2. Set static IP: sudo ip addr add <IP>/<MASK> dev <interface>"
            echo "  3. Check DHCP server is running"
            echo "  4. Restart networking: sudo systemctl restart systemd-networkd"
            ;;
        "$EXIT_L3_NO_ROUTE")
            echo "Issue: No route to destination"
            echo ""
            echo "Solutions:"
            echo "  1. Add default route: sudo ip route add default via <GATEWAY>"
            echo "  2. Check routing table: ip route show"
            echo "  3. Restart networking service"
            ;;
        "$EXIT_L3_GATEWAY_UNREACHABLE")
            echo "Issue: Gateway not responding to ICMP"
            echo ""
            echo "Solutions:"
            echo "  1. Check gateway is online"
            echo "  2. Verify gateway IP is correct: ip route show"
            echo "  3. Gateway may block ICMP (try L4 test)"
            ;;
        "$EXIT_L3_DESTINATION_UNREACHABLE")
            echo "Issue: Destination not responding to ICMP"
            echo ""
            echo "Solutions:"
            echo "  1. Check destination is online"
            echo "  2. Destination may block ICMP (try L4 test)"
            echo "  3. Check for routing issues: traceroute <destination>"
            ;;
    esac
    echo ""
}

analyze_l4_failure() {
    local exit_code="$1"
    
    log_header "Layer 4 Recommendations"
    
    case "$exit_code" in
        "$EXIT_L4_PORT_CLOSED")
            echo "Issue: TCP port closed or connection refused"
            echo ""
            echo "Solutions:"
            echo "  1. Verify service is running on destination"
            echo "  2. Check correct port number"
            echo "  3. Check destination firewall"
            echo "  4. Verify no NAT/port forwarding issues"
            ;;
        "$EXIT_L4_CONNECTION_TIMEOUT")
            echo "Issue: Connection attempt timed out"
            echo ""
            echo "Solutions:"
            echo "  1. Destination may be offline"
            echo "  2. Firewall may be silently dropping packets"
            echo "  3. Check for intermediate firewall/NAT issues"
            echo "  4. Increase timeout and retry"
            ;;
    esac
    echo ""
}

analyze_fw_failure() {
    local exit_code="$1"
    
    log_header "Firewall Recommendations"
    
    case "$exit_code" in
        "$EXIT_FW_EXPLICIT_BLOCK")
            echo "Issue: Firewall has explicit rule blocking traffic"
            echo ""
            echo "Solutions:"
            echo "  1. Review firewall rules: sudo iptables -L -n -v"
            echo "  2. Allow traffic: sudo ufw allow <port>"
            echo "  3. Check nftables: sudo nft list ruleset"
            echo "  4. Temporarily disable for testing: sudo ufw disable"
            ;;
        "$EXIT_FW_DEFAULT_POLICY_DROP")
            echo "Issue: Firewall default policy drops traffic"
            echo ""
            echo "Solutions:"
            echo "  1. Add explicit allow rule for destination"
            echo "  2. Review and adjust firewall policy"
            echo "  3. Use more permissive policy for testing"
            ;;
    esac
    echo ""
}

# -------- JSON Output --------

output_json() {
    local destination="$1"
    local port="$2"
    shift 2
    local results=("$@")
    
    echo "{"
    json_key_value "timestamp" "$(get_timestamp_iso)"
    echo ","
    json_key_value "destination" "$destination"
    echo ","
    json_key_value "port" "$port"
    echo ","
    echo "  \"layers\": {"
    
    local first=true
    local i
    for i in "${!results[@]}"; do
        local layer="${results[$i]%%:*}"
        local exit_code="${results[$i]#*:}"
        
        if [[ "$first" == false ]]; then
            echo ","
        fi
        first=false
        
        echo -n "    \"$layer\": {"
        echo -n "\"exit_code\": $exit_code, "
        echo -n "\"status\": "
        if [[ $exit_code -eq 0 ]]; then
            echo -n "\"pass\""
        else
            echo -n "\"fail\""
        fi
        echo -n ", "
        json_key_value "description" "$(get_exit_code_description "$exit_code")"
        echo -n "}"
    done
    
    echo ""
    echo "  }"
    echo "}"
}

# -------- Main --------

main() {
    local args destination port
    
    require_root || exit "$EXIT_PERMISSION_DENIED"
    
    args=$(parse_arguments "$@")
    read -r destination port <<< "$args"
    
    if [[ "$JSON_OUTPUT" == false && "$QUIET" == false ]]; then
        log_header "Advanced Network Analysis"
        log_info "Target: $destination:$port"
        log_info "Time: $(get_timestamp)"
        echo ""
    fi
    
    # Run all layer checks
    local l2_result l3_result l4_result fw_result
    local results=()
    local total_checks=0 passed_checks=0
    
    # Layer 2
    if [[ "$QUIET" == false ]]; then
        log_header "Layer 2: Link Layer"
    fi
    l2_result=$(run_layer_check "l2_link.sh" "$destination")
    IFS='|' read -r l2_exit l2_output <<< "$l2_result"
    results+=("L2:$l2_exit")
    total_checks=$((total_checks + 1))
    [[ $l2_exit -eq 0 ]] && passed_checks=$((passed_checks + 1))
    
    if [[ "$VERBOSE" == true || $l2_exit -ne 0 ]]; then
        echo "$l2_output"
    fi
    [[ $l2_exit -ne 0 ]] && analyze_result "L2" "$l2_exit" "$l2_output"
    
    # Layer 3
    if [[ "$QUIET" == false ]]; then
        log_header "Layer 3: Network Layer"
    fi
    l3_result=$(run_layer_check "l3_network.sh" "$destination")
    IFS='|' read -r l3_exit l3_output <<< "$l3_result"
    results+=("L3:$l3_exit")
    total_checks=$((total_checks + 1))
    [[ $l3_exit -eq 0 ]] && passed_checks=$((passed_checks + 1))
    
    if [[ "$VERBOSE" == true || $l3_exit -ne 0 ]]; then
        echo "$l3_output"
    fi
    [[ $l3_exit -ne 0 ]] && analyze_result "L3" "$l3_exit" "$l3_output"
    
    # Layer 4
    if [[ "$QUIET" == false ]]; then
        log_header "Layer 4: Transport Layer"
    fi
    l4_result=$(run_layer_check "l4_transport.sh" "$destination" "$port" "tcp")
    IFS='|' read -r l4_exit l4_output <<< "$l4_result"
    results+=("L4:$l4_exit")
    total_checks=$((total_checks + 1))
    [[ $l4_exit -eq 0 ]] && passed_checks=$((passed_checks + 1))
    
    if [[ "$VERBOSE" == true || $l4_exit -ne 0 ]]; then
        echo "$l4_output"
    fi
    [[ $l4_exit -ne 0 ]] && analyze_result "L4" "$l4_exit" "$l4_output"
    
    # Firewall
    if [[ "$QUIET" == false ]]; then
        log_header "Firewall Layer"
    fi
    fw_result=$(run_layer_check "firewall.sh" "$destination" "$port")
    IFS='|' read -r fw_exit fw_output <<< "$fw_result"
    results+=("FW:$fw_exit")
    total_checks=$((total_checks + 1))
    [[ $fw_exit -eq 0 || $fw_exit -eq 42 ]] && passed_checks=$((passed_checks + 1))
    
    if [[ "$VERBOSE" == true || $fw_exit -ne 0 ]]; then
        echo "$fw_output"
    fi
    [[ $fw_exit -ne 0 && $fw_exit -ne 42 ]] && analyze_result "FW" "$fw_exit" "$fw_output"
    
    # Output results
    if [[ "$JSON_OUTPUT" == true ]]; then
        output_json "$destination" "$port" "${results[@]}"
    else
        log_header "Analysis Summary"
        echo ""
        printf "Checks passed: %d/%d\n" "$passed_checks" "$total_checks"
        echo ""
        
        if [[ $passed_checks -eq $total_checks ]]; then
            log_success "All network layers permit communication to $destination:$port"
            exit 0
        else
            log_error "Network communication is blocked or degraded"
            echo ""
            log_info "Review recommendations above for specific solutions"
            exit 1
        fi
    fi
}

main "$@"