#!/usr/bin/env bash

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
# Filename:   ebpf-requirements.sh
# Purpose:    Checks host kernel configuration for required eBPF options for Cilium.
# Author:     Your Name
# Date:       2025-11-09
# Version:    1.1.0
# Run: curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/ebpf-requirements.sh | bash

# --- Configuration ---
set -euo pipefail
# set -x # Uncomment for debugging

# ==============================================================================
# GLOBAL STATE
# ==============================================================================
declare -i failures=0
declare -a failed_items=()

# ==============================================================================
# FUNCTION: get_config_file
# ==============================================================================
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
# TEST GROUP: Base Requirements
# ==============================================================================
test_base_requirements() {
  local cfg group_failed=0
  cfg=$(get_config_file)
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
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# TEST GROUP: Iptables-based Masquerading
# ==============================================================================
test_iptables_masquerading() {
  local cfg group_failed=0
  cfg=$(get_config_file)
  for opt in \
    CONFIG_NETFILTER_XT_SET \
    CONFIG_IP_SET \
    CONFIG_IP_SET_HASH_IP \
    CONFIG_NETFILTER_XT_MATCH_COMMENT; do
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# TEST GROUP: Tunneling and Routing
# ==============================================================================
test_tunneling_routing() {
  local cfg group_failed=0
  cfg=$(get_config_file)
  for opt in \
    CONFIG_VXLAN \
    CONFIG_GENEVE \
    CONFIG_FIB_RULES; do
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# TEST GROUP: L7 and FQDN Policies
# ==============================================================================
test_l7_fqdn_policies() {
  local cfg group_failed=0
  cfg=$(get_config_file)
  for opt in \
    CONFIG_NETFILTER_XT_TARGET_TPROXY \
    CONFIG_NETFILTER_XT_TARGET_MARK \
    CONFIG_NETFILTER_XT_TARGET_CT \
    CONFIG_NETFILTER_XT_MATCH_MARK \
    CONFIG_NETFILTER_XT_MATCH_SOCKET; do
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# TEST GROUP: Requirements for IPsec
# ==============================================================================
test_ipsec_requirements() {
  local cfg group_failed=0
  cfg=$(get_config_file)
  for opt in \
    CONFIG_XFRM \
    CONFIG_XFRM_OFFLOAD \
    CONFIG_XFRM_STATISTICS \
    CONFIG_XFRM_ALGO \
    CONFIG_XFRM_USER \
    CONFIG_INET_ESP \
    CONFIG_INET6_ESP \
    CONFIG_INET_IPCOMP \
    CONFIG_INET6_IPCOMP \
    CONFIG_INET_XFRM_TUNNEL \
    CONFIG_INET6_XFRM_TUNNEL \
    CONFIG_INET_TUNNEL \
    CONFIG_INET6_TUNNEL \
    CONFIG_INET_XFRM_MODE_TUNNEL \
    CONFIG_CRYPTO_AEAD \
    CONFIG_CRYPTO_AEAD2 \
    CONFIG_CRYPTO_GCM \
    CONFIG_CRYPTO_SEQIV \
    CONFIG_CRYPTO_CBC \
    CONFIG_CRYPTO_HMAC \
    CONFIG_CRYPTO_SHA256 \
    CONFIG_CRYPTO_AES; do
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# TEST GROUP: Bandwidth Manager Requirements
# ==============================================================================
test_bandwidth_manager() {
  local cfg group_failed=0
  cfg=$(get_config_file)
  for opt in CONFIG_NET_SCH_FQ; do
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# TEST GROUP: Netkit Device Mode Requirements
# ==============================================================================
test_netkit_device_mode() {
  local cfg group_failed=0
  cfg=$(get_config_file)
  for opt in CONFIG_NETKIT; do
    local val
    if [[ "${cfg##*.}" == "gz" ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] - $val"
    else
      echo "[FAIL] - $opt"
      failed_items+=("$opt")
      group_failed=1
    fi
  done
  return $group_failed
}

# ==============================================================================
# MAIN EXECUTION & SUMMARY
# ==============================================================================
echo "===================================="
echo "=== eBPF Requirements Checks ======="
echo "===================================="

echo "==== A. Base Requirements"
test_base_requirements || ((failures++))

echo "==== B. Iptables-based Masquerading"
test_iptables_masquerading || ((failures++))

echo "==== C. Tunneling and Routing"
test_tunneling_routing || ((failures++))

echo "==== D. L7 and FQDN Policies"
test_l7_fqdn_policies || ((failures++))

echo "==== E. Requirements for IPsec"
test_ipsec_requirements || ((failures++))

echo "==== F. Bandwidth Manager Requirements"
test_bandwidth_manager || ((failures++))

echo "==== G. Netkit Device Mode Requirements"
test_netkit_device_mode || ((failures++))

echo
echo "=================================================="
echo "=============== Summary Report =================="
echo "=================================================="
if [ $failures -eq 0 ]; then
  echo "### ALL PASS: All eBPF requirements satisfied ###"
  exit 0
else
  echo "### FAIL: $failures failures detected ###"
  echo
  echo "Failed items:"
  for item in "${failed_items[@]}"; do
    echo "- $item"
  done
  exit 1
fi
