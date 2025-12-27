Contributing to Host Network Permission Analyzer
Thank you for your interest in contributing! This guide will help you get started.

🎯 Project Goals
This project aims to:

Help sysadmins troubleshoot network issues quickly and systematically
Teach Bash scripting through practical, real-world examples
Follow best practices in shell scripting and Linux system administration
Remain portable across different Linux distributions
🚀 Getting Started
Prerequisites
Linux system (Ubuntu, Debian, Fedora, etc.)
Bash 4.0 or later
Root access for testing
Git installed
ShellCheck installed (recommended)
bash
# Install ShellCheck
sudo apt install shellcheck  # Ubuntu/Debian
sudo dnf install ShellCheck  # Fedora
Fork and Clone
bash
# Fork the repository on GitHub first

# Clone your fork
git clone https://github.com/YOUR_USERNAME/host-network-permission-analyzer.git
cd host-network-permission-analyzer

# Add upstream remote
git remote add upstream https://github.com/girpyx/host-network-permission-analyzer.git
📝 Code Style Guidelines
Bash Best Practices
1. Always use strict error handling

bash
#!/usr/bin/env bash
set -euo pipefail
2. Declare all variables as local

bash
my_function() {
    local target="$1"
    local result
    
    result=$(some_command "$target")
    echo "$result"
}
3. Use readonly for constants

bash
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_PREFIX="[L2]"
4. Always quote variables

bash
# Good
if [[ -z "$variable" ]]; then
    echo "$variable"
fi

# Bad - can cause word splitting
if [[ -z $variable ]]; then
    echo $variable
fi
5. Check command availability

bash
if ! command -v tool_name >/dev/null 2>&1; then
    log "tool_name not available, skipping"
    return 0
fi
6. Use meaningful function names

bash
# Good
check_wifi_association() { ... }
detect_interface() { ... }

# Avoid
wifi_check() { ... }
get_iface() { ... }
7. Document exit codes

bash
# At the top of each script
# Exit Codes:
#   0  - Success
#   1  - Permission denied
#   10 - Specific error condition
File Structure Template
Use this structure for new diagnostic scripts:

bash
#!/usr/bin/env bash
# Brief description of what this script does
#
# Usage: sudo ./script_name.sh [ARGS]
#
# Exit Codes:
#   0  - Success
#   1  - Permission error
#   N  - Specific failure modes

set -euo pipefail

# -------- Configuration --------

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_PREFIX="[LAYER]"

# -------- Helpers --------

log() {
    printf '%s %s\n' "$LOG_PREFIX" "$1"
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

# -------- Checks --------

check_something() {
    local param="$1"
    # Implementation
}

# -------- Main --------

main() {
    local target="${1:-default_value}"
    
    require_root
    check_something "$target"
    
    log "Check passed"
    exit 0
}

main "$@"
🧪 Testing Your Changes
Manual Testing
bash
# Test your script directly
sudo ./scripts/checks/your_script.sh

# Test with different targets
sudo ./scripts/checks/your_script.sh 8.8.8.8
sudo ./scripts/checks/your_script.sh 192.168.1.1

# Test error conditions
# Example: disconnect network and test
sudo ip link set eth0 down
sudo ./scripts/checks/your_script.sh
sudo ip link set eth0 up
ShellCheck Validation
bash
# Check single file
shellcheck scripts/checks/your_script.sh

# Check all scripts
shellcheck scripts/checks/*.sh diagnose.sh
Fix all warnings and errors before submitting.

Exit Code Testing
bash
# Verify exit codes
sudo ./scripts/checks/your_script.sh
echo "Exit code: $?"

# Test failure modes
# (create conditions that should fail)
sudo ./scripts/checks/your_script.sh
echo "Exit code: $?"
📋 Commit Message Format
Use Conventional Commits format:

<type>(<scope>): <subject>

<body>

<footer>
Types
feat: New feature
fix: Bug fix
docs: Documentation changes
style: Code style changes (formatting, no logic change)
refactor: Code refactoring
test: Adding or updating tests
chore: Maintenance tasks
Scopes
l2: Layer 2 diagnostics
l3: Layer 3 diagnostics
l4: Layer 4 diagnostics
firewall: Firewall diagnostics
core: Core functionality
docs: Documentation
Examples
bash
# Adding new feature
git commit -m "feat(l5): add DNS resolution diagnostics

- Check /etc/resolv.conf configuration
- Test DNS server reachability
- Perform actual DNS lookups
- Exit code 50 for DNS failures

Helps diagnose DNS-related connectivity issues"

# Fixing a bug
git commit -m "fix(l3): handle IPv6-only interfaces

Previously failed when only IPv6 was configured.
Now checks for both IPv4 and IPv6 addresses."

# Documentation update
git commit -m "docs: add troubleshooting scenarios to README

Added common scenarios:
- WiFi connected but no internet
- Web server not accessible
- SSH connection refused"
🌿 Branch Workflow
Create Feature Branch
bash
# Update your main branch
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/dns-resolution-check
Branch Naming
feature/ - New features
fix/ - Bug fixes
docs/ - Documentation updates
refactor/ - Code refactoring
Examples:

feature/dns-resolution
fix/l2-wifi-detection
docs/add-examples
Making Changes
bash
# Make your changes
# Test thoroughly
# Run ShellCheck

# Stage changes
git add scripts/checks/new_script.sh

# Commit with descriptive message
git commit -m "feat(l5): add DNS resolution checks"

# Push to your fork
git push origin feature/dns-resolution-check
🔄 Pull Request Process
Before Submitting
 Code follows project style guidelines
 All ShellCheck warnings resolved
 Tested on at least one Linux distribution
 Documentation updated (README.md)
 Commit messages follow conventional format
 No merge conflicts with main branch
Submitting PR
Push your branch to your fork
Go to GitHub and create Pull Request
Fill out PR template:
markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Code refactoring

## Testing
Describe how you tested this:
- Tested on Ubuntu 22.04
- Ran ShellCheck
- Tested with targets: 8.8.8.8, 192.168.1.1

## Checklist
- [x] Code follows style guidelines
- [x] ShellCheck passes
- [x] Documentation updated
- [x] Commit messages follow format
Review Process
Maintainer reviews code
Feedback provided (if needed)
Make requested changes
Push updates to same branch
Maintainer approves and merges
💡 Ideas for Contributions
High Priority
 DNS resolution diagnostics (L7)
 SSL/TLS certificate validation
 Full IPv6 support throughout
 MTU path discovery checks
 Network namespace detection
Medium Priority
 JSON output mode
 Logging to file option
 Color output toggle
 Verbose mode
 Quiet mode (errors only)
Nice to Have
 Web interface for results
 Email notification on failures
 Integration with monitoring systems
 Performance metrics
 Historical tracking
Documentation
 More troubleshooting examples
 Video tutorials
 Architecture diagrams
 Man pages
 Translations
🐛 Reporting Bugs
Before Reporting
Check existing issues
Test with latest version
Verify it's not a local configuration issue
Bug Report Format
markdown
**Description**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Run command '...'
2. See error

**Expected Behavior**
What you expected to happen

**Environment**
- OS: Ubuntu 22.04
- Bash version: 5.1.16
- Script version: commit abc123

**Additional Context**
Any other relevant information
📚 Resources for Contributors
Bash Scripting
Bash Reference Manual
Google Shell Style Guide
ShellCheck Wiki
Linux Networking
man ip - iproute2 documentation
man iptables, man nft - firewall docs
Linux Network Stack
Git and GitHub
GitHub Flow
Conventional Commits
❓ Questions?
Open a GitHub issue with the question label
Start a GitHub Discussion
Check existing documentation
🙏 Thank You!
Every contribution helps make this tool better for the community. Whether it's:

Reporting a bug
Suggesting a feature
Improving documentation
Writing code
Your help is appreciated! 🎉

