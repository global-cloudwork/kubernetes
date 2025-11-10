#!/usr/bin/env bash

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
# Filename:   ebpf-requirements.sh
# Purpose:    Checks host kernel configuration for required eBPF options for Cilium.
# Author:     Your Name
# Date:       2025-11-09
# Version:    1.0.0
# Run: curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/ebpf-requirements.sh | bash

# --- Configuration ---
set -euo pipefail
# set -x # Uncomment for debugging

# ==============================================================================
# ERROR CODES
# ==============================================================================
# 0 - Success
# 1 - Generic/Unknown Error
# 2 - Invalid Input/Argument Error
# 3 - Dependency Not Found
# 4 - Operation Failed
# 5 - Permission Denied

# ==============================================================================
# FUNCTION: check_requirement
# ==============================================================================
# Purpose:    Run a command string, report pass/fail with name, return status.
# Arguments:  $1 - Descriptive name for the requirement
#             $2 - Command string to evaluate
# Returns:    0 if pass, non-zero on failure
check_requirement() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd"; then
    echo "[PASS] $name"
    return 0
  else
    echo "[FAIL] $name"
    return 1
  fi
}

# ==============================================================================
# FUNCTION: get_config_file
# ==============================================================================
# Purpose:    Determine the kernel config file location
get_config_file() {
  if [ -f /proc/config.gz ]; then
    echo "/proc/config.gz"
  elif [ -f /boot/config-$(uname -r) ]; then
    echo "/boot/config-$(uname -r)"
  else
    echo "[FAIL] Kernel config file not found" >&2
    exit 1
  fi
}

# ==============================================================================
# TEST GROUPS
# ==============================================================================

test_base_requirements() {
  local config_file
  config_file=$(get_config_file)
  echo "Checking base eBPF kernel options in $config_file"
  for opt in \
    CONFIG_BPF \
    CONFIG_BPF_SYSCALL \
    CONFIG_NET_CLS_BPF \
    CONFIG_BPF_JIT \
    CONFIG_NET_CLS_ACT \
    CONFIG_NET_SCH_INGRESS \
    CONFIG_CRYPTO_SHA1 \
    CONFIG_CRYPTO_USER_API_HASH \
    CONFIG_CGROUPS \
    CONFIG_CGROUP_BPF \
    CONFIG_PERF_EVENTS \
    CONFIG_SCHEDSTATS; do
    check_requirement "$opt" "if [[ \"${config_file##*.}\" == \"gz\" ]]; then zgrep -E '^$opt=(y|m)' \"$config_file\"; else grep -E '^$opt=(y|m)' \"$config_file\"; fi"
  done
}

test_iptables_masquerading() {
  local config_file
  config_file=$(get_config_file)
  echo "Checking iptables-based masquerading options in $config_file"
  for opt in \
    CONFIG_NETFILTER_XT_SET \
    CONFIG_IP_SET \
    CONFIG_IP_SET_HASH_IP \
    CONFIG_NETFILTER_XT_MATCH_COMMENT; do
    check_requirement "$opt" "if [[ \"${config_file##*.}\" == \"gz\" ]]; then zgrep -E '^$opt=(y|m)' \"$config_file\"; else grep -E '^$opt=(y|m)' \"$config_file\"; fi"
  done
}

test_tunneling_routing() {
  local config_file
  config_file=$(get_config_file)
  echo "Checking tunneling and routing options in $config_file"
  for opt in \
    CONFIG_VXLAN \
    CONFIG_GENEVE \
    CONFIG_FIB_RULES; do
    check_requirement "$opt" "if [[ \"${config_file##*.}\" == \"gz\" ]]; then zgrep -E '^$opt=(y|m)' \"$config_file\"; else grep -E '^$opt=(y|m)' \"$config_file\"; fi"
  done
}

test_l7_fqdn_policies() {
  local config_file
  config_file=$(get_config_file)
  echo "Checking L7 / FQDN policy kernel options in $config_file"
  for opt in \
    CONFIG_NETFILTER_XT_TARGET_TPROXY \
    CONFIG_NETFILTER_XT_TARGET_MARK \
    CONFIG_NETFILTER_XT_TARGET_CT \
    CONFIG_NETFILTER_XT_MATCH_MARK \
    CONFIG_NETFILTER_XT_MATCH_SOCKET; do
    check_requirement "$opt" "if [[ \"${config_file##*.}\" == \"gz\" ]]; then zgrep -E '^$opt=(y|m)' \"$config_file\"; else grep -E '^$opt=(y|m)' \"$config_file\"; fi"
  done
}

# ==============================================================================
# MAIN EXECUTION & SUMMARY
# ==============================================================================
echo "--- eBPF Requirements Checks ---"
declare -i failures=0

echo -e "\n[TEST A] Base Requirements"
test_base_requirements || ((failures++))

echo -e "\n[TEST B] Iptables-based Masquerading"
test_iptables_masquerading || ((failures++))

echo -e "\n[TEST C] Tunneling and Routing"
test_tunneling_routing || ((failures++))

echo -e "\n[TEST D] L7 and FQDN Policies"
test_l7_fqdn_policies || ((failures++))

echo -e "\n--- Summary ---"
if [ $failures -eq 0 ]; then
  echo "[PASS] All eBPF requirements satisfied"
  exit 0
else
  echo "[FAIL] $failures test group(s) had failures"
  exit 1
fi
