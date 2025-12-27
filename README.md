Host Network Permission Analyzer
A comprehensive Bash-based diagnostic framework for Linux systems that systematically analyzes network connectivity across the entire network stack. Perfect for troubleshooting connectivity issues and learning how Linux networking works.

🎯 What This Does
When you can't reach a network destination, this toolkit tells you exactly where the problem is:

Layer 2 (Link): Is your network cable plugged in? Is WiFi associated?
Layer 3 (Network): Do you have an IP address? Can you route packets?
Layer 4 (Transport): Is the port open? Can you establish TCP connections?
Firewall: Are your firewall rules blocking traffic?
🚀 Quick Start
bash
# Clone the repository
git clone https://github.com/girpyx/host-network-permission-analyzer.git
cd host-network-permission-analyzer

# Make scripts executable
chmod +x diagnose.sh
chmod +x scripts/checks/*.sh

# Run full diagnostic (requires root)
sudo ./diagnose.sh 8.8.8.8 80

# Or run individual layer checks
sudo ./scripts/checks/l2_link.sh 8.8.8.8
sudo ./scripts/checks/l3_network.sh 8.8.8.8
sudo ./scripts/checks/l4_transport.sh 8.8.8.8 80
sudo ./scripts/checks/firewall.sh 8.8.8.8 80
📋 Requirements
Required:

Root access (CAP_NET_ADMIN capability)
ip command (iproute2 package)
Bash 4.0 or later
Optional (but recommended):

iw - for WiFi diagnostics
rfkill - for wireless blocking detection
nc (netcat) - for port connectivity tests
ping - for ICMP reachability tests
Installation on Ubuntu/Debian:

bash
sudo apt install iproute2 wireless-tools rfkill netcat-openbsd iputils-ping
📁 Project Structure
host-network-permission-analyzer/
├── diagnose.sh              # Master script - runs all checks
├── scripts/
│   └── checks/
│       ├── l2_link.sh       # Layer 2: Link layer diagnostics
│       ├── l3_network.sh    # Layer 3: Network layer diagnostics
│       ├── l4_transport.sh  # Layer 4: Transport layer diagnostics
│       └── firewall.sh      # Firewall rules analysis
└── README.md
🔍 Layer-by-Layer Breakdown
Layer 2: Link Layer (l2_link.sh)
What it checks:

✓ RF kill blocking (hardware/software wireless blocks)
✓ Interface state (UP/DOWN)
✓ Physical carrier presence (cable plugged in)
✓ WiFi association status
✓ ARP/NDP neighbor reachability
Example output:

[L2] routed interface: wlan0
[L2] rfkill: OK
[L2] interface state: UP with carrier
[L2] wifi association: OK
[L2] neighbor reachability: OK (192.168.1.1)
[L2] L2 communication permitted on wlan0
Exit codes:

0 - L2 communication permitted
10 - RF kill blocking detected
11 - Interface down or no route
12 - No carrier (cable unplugged)
13 - WiFi not associated
14 - Gateway unreachable at L2
Layer 3: Network Layer (l3_network.sh)
What it checks:

✓ IP address assignment (IPv4 and IPv6)
✓ Routing table entries
✓ Gateway reachability (ICMP)
✓ Destination reachability (ICMP)
Example output:

[L3] routed interface: wlan0
[L3] IPv4 address present on wlan0
[L3] route exists: 8.8.8.8 via 192.168.1.1 dev wlan0 src 192.168.1.100
[L3] gateway detected: 192.168.1.1
[L3] gateway reachable via ICMP
[L3] destination reachable via ICMP
[L3] L3 communication permitted to 8.8.8.8
Exit codes:

0 - L3 communication permitted
20 - No IP address assigned
21 - No route to destination
22 - Gateway unreachable
23 - Destination unreachable
Layer 4: Transport Layer (l4_transport.sh)
What it checks:

✓ TCP port connectivity
✓ UDP packet transmission (limited reliability)
✓ Local port bindings
Example usage:

bash
# Check if port 80 is reachable
sudo ./scripts/checks/l4_transport.sh 8.8.8.8 80 tcp

# Check UDP port 53 (DNS)
sudo ./scripts/checks/l4_transport.sh 8.8.8.8 53 udp
Exit codes:

0 - L4 communication permitted
30 - Port closed or connection refused
31 - Connection timeout
32 - Required tools not available
Firewall Layer (firewall.sh)
What it checks:

✓ Detects firewall type (iptables, nftables, ufw, firewalld)
✓ Analyzes default policies
✓ Checks for explicit DROP/REJECT rules
✓ Examines chain rules and rich rules
Supported firewalls:

iptables (legacy)
nftables (modern)
ufw (Ubuntu/Debian frontend)
firewalld (RHEL/Fedora frontend)
Exit codes:

0 - Firewall permits communication
40 - Explicit blocking rule found
41 - Default policy blocks traffic
42 - No firewall detected (informational)
💡 Common Troubleshooting Scenarios
Scenario 1: "I can't ping Google"
bash
sudo ./diagnose.sh 8.8.8.8
The diagnostic will show you exactly which layer is failing:

L2 fails → Check your cable or WiFi connection
L3 fails → Check your IP configuration or routing
L4 passes but ping fails → ICMP might be blocked
Firewall fails → Check your firewall rules
Scenario 2: "My web server isn't accessible"
bash
sudo ./diagnose.sh 192.168.1.100 80
This checks:

Can you reach the server at L2/L3?
Is port 80 open?
Is your firewall blocking it?
Scenario 3: "WiFi connected but no internet"
bash
sudo ./scripts/checks/l2_link.sh 8.8.8.8
sudo ./scripts/checks/l3_network.sh 8.8.8.8
This isolates whether it's:

Association issue (L2)
DHCP/routing issue (L3)
DNS issue (not covered yet - coming soon!)
🛠️ Development Guide
Code Style Guidelines
This project follows these Bash best practices:

Use local for all function variables
bash
   my_function() {
       local my_var="value"
       # ...
   }
Pass parameters explicitly, avoid globals
bash
   # Good
   check_something() {
       local target="$1"
   }
   
   # Avoid
   check_something() {
       # Uses global $TARGET
   }
Always quote variables
bash
   echo "$variable"       # Good
   echo $variable         # Bad
Use meaningful exit codes
bash
   exit 0   # Success
   exit 1   # Permission error
   exit 10+ # Specific failures
Check command availability
bash
   if ! command -v tool >/dev/null 2>&1; then
       log "tool not available"
       return 0
   fi
Adding a New Layer Check
Create new script in scripts/checks/
Follow the template structure:
bash
   #!/usr/bin/env bash
   set -euo pipefail
   
   # Configuration
   readonly LOG_PREFIX="[LAYER]"
   
   # Helpers (log, fail, require_root)
   # Checks (individual functions)
   # Main function
   
   main "$@"
Add to diagnose.sh master script
Update this README
Test thoroughly
Commit with descriptive message
Git Workflow
bash
# Create feature branch
git checkout -b feature/dns-resolution-check

# Make changes
# Test your changes

# Commit with conventional commits format
git commit -m "feat(l7): add DNS resolution diagnostics

- Check /etc/resolv.conf configuration
- Test DNS server reachability
- Perform actual DNS lookups
- Exit code 50 for DNS resolution failures"

# Push and create pull request
git push origin feature/dns-resolution-check
🧪 Testing
Test each script individually:

bash
# Test L2 with various targets
sudo ./scripts/checks/l2_link.sh 127.0.0.1  # Should detect loopback
sudo ./scripts/checks/l2_link.sh 8.8.8.8    # Normal test
sudo ./scripts/checks/l2_link.sh 192.168.1.1  # Local gateway

# Test error conditions
sudo ip link set wlan0 down
sudo ./scripts/checks/l2_link.sh 8.8.8.8  # Should fail with exit 11
sudo ip link set wlan0 up
Run ShellCheck for code quality:

bash
shellcheck scripts/checks/*.sh diagnose.sh
📚 Learning Resources
This project is designed to help you learn Bash scripting and Linux networking:

Bash Scripting:

Bash Reference Manual
ShellCheck - catches common mistakes
Google's Shell Style Guide
Linux Networking:

man ip - iproute2 documentation
man iptables / man nft - firewall documentation
Linux Network Stack
🤝 Contributing
Contributions welcome! Areas for improvement:

 DNS resolution checks (L7)
 SSL/TLS certificate validation
 IPv6 dual-stack support
 Network namespace awareness
 JSON output mode for monitoring integration
 Web interface for results
 Automated test suite


👤 Author
girpyx

GitHub: @girpyx
Project: host-network-permission-analyzer
🙏 Acknowledgments
Built with insights from:

Linux kernel networking documentation
iproute2 utility suite
Community feedback and contributions
Questions? Open an issue on GitHub! Found this helpful? Give it a ⭐!

