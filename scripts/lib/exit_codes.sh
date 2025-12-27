#!/usr/bin/env bash
# Centralized exit codes for host-network-permission-analyzer

# Success
readonly EXIT_OK=0

# General
readonly EXIT_INVALID_ARGS=2
readonly EXIT_MISSING_TOOLS=3
readonly EXIT_PERMISSION_DENIED=4

# Layer 2 – Link
readonly EXIT_L2_RFKILL_BLOCKED=20
readonly EXIT_L2_INTERFACE_DOWN=21
readonly EXIT_L2_NO_CARRIER=22
readonly EXIT_L2_WIFI_NOT_ASSOCIATED=23
readonly EXIT_L2_NEIGHBOR_UNREACHABLE=24

# Layer 3 – Network
readonly EXIT_L3_NO_IP_ADDRESS=30
readonly EXIT_L3_NO_ROUTE=31
readonly EXIT_L3_GATEWAY_UNREACHABLE=32
readonly EXIT_L3_DESTINATION_UNREACHABLE=33

# Layer 4 – Transport
readonly EXIT_L4_PORT_CLOSED=40
readonly EXIT_L4_CONNECTION_TIMEOUT=41
readonly EXIT_L4_UDP_UNCERTAIN=42



# Firewall
readonly EXIT_FW_EXPLICIT_BLOCK=50
readonly EXIT_FW_DEFAULT_POLICY_DROP=51

# Firewall informational / not applicable
readonly EXIT_FW_NOT_PRESENT=42
