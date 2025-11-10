#!/usr/bin/env bash

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
# Filename:   system-requirements.sh
# Purpose:    Checks host compatibility for Cilium system requirements, including kernel eBPF configuration options.
# Author:     Your Name
# Date:       2025-11-10
# Version:    2.0.0
# Run: curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/system-requirements.sh | bash

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
# HELPER FUNCTION: version_ge (semantic version comparison)
# ==============================================================================
version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1 | grep -qx "$2"
}

# ==============================================================================
# SPECIFIC CHECKS (System)
# ==============================================================================
check_architecture() {
  local arch_name
  arch_name=$(uname -m)
  case "$arch_name" in
    x86_64) arch_name="AMD64" ;;
    aarch64) arch_name="AArch64" ;;
  esac
  check_requirement "Architecture: $arch_name" \
    "[[ \"$arch_name\" == \"AMD64\" || \"$arch_name\" == \"AArch64\" ]]"
}

check_kernel() {
  local full base
  full=$(uname -r)
  base=${full%%-*}
  check_requirement "Kernel: $full" \
    "version_ge \"$base\" \"5.10\" || version_ge \"$base\" \"4.18\""
}

check_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
      if version_ge "$VERSION_ID" "20.04"; then
        echo "[PASS] OS: $NAME $VERSION_ID"
      else
        echo "[FAIL] OS: $NAME $VERSION_ID (requires Ubuntu >=20.04)"
        return 1
      fi
    else
      echo "[FAIL] OS: $NAME $VERSION_ID (unsupported)"
      return 1
    fi
  else
    echo "[FAIL] OS: Unknown (requires Ubuntu >=20.04)"
    return 1
  fi
}

check_etcd() {
  local count
  if ! count=$(/var/lib/rancher/rke2/bin/kubectl get pods -n kube-system -l component=etcd 2>/dev/null | awk 'NR>1 && $3=="Running" {c++} END{print c+0}'); then
    echo "[FAIL] etcd: kubectl command failed"
    return 1
  fi
  if [ "$count" -ge 1 ]; then
    echo "[PASS] etcd: Running"
    return 0
  else
    echo "[FAIL] etcd: not found or not Running"
    return 1
  fi
}

# ==============================================================================
# eBPF Requirements Checks
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
echo "--- Demonstration of System Requirements Checks ---"
echo

declare -i failures=0
declare -a failed_items=()

echo -e "\n[TEST A] Architecture"
check_architecture || ((failures++))

echo -e "\n[TEST B] Kernel"
check_kernel || ((failures++))

echo -e "\n[TEST C] OS Version"
check_os || ((failures++))

echo -e "\n[TEST D] etcd"
check_etcd || ((failures++))

echo -e "\n[TEST E] eBPF Base Requirements"
test_base_requirements || ((failures++))

echo -e "\n[TEST F] Iptables-based Masquerading"
test_iptables_masquerading || ((failures++))

echo -e "\n[TEST G] Tunneling and Routing"
test_tunneling_routing || ((failures++))

echo -e "\n[TEST H] L7 and FQDN Policies"
test_l7_fqdn_policies || ((failures++))

echo -e "\n[TEST I] Requirements for IPsec"
test_ipsec_requirements || ((failures++))

echo -e "\n[TEST J] Bandwidth Manager Requirements"
test_bandwidth_manager || ((failures++))

echo -e "\n[TEST K] Netkit Device Mode Requirements"
test_netkit_device_mode || ((failures++))

echo -e "\n--- Summary ---"
if [ $failures -eq 0 ]; then
  echo "[PASS] All checks passed"
  exit 0
else
  echo "[FAIL] $failures check(s) failed"
  echo
  echo "Failed items:"
  for item in "${failed_items[@]}"; do
    echo "- $item"
  done
  exit 1
fi
