#!/usr/bin/env bash
# ==============================================================================
# Filename:   system-requirements.sh
# Purpose:    Validate host compatibility for Kubernetes/Cilium requirements.
# Author:     Your Name
# Date:       2025-11-10
# Version:    3.0.0
# Usage:      bash scripts/tests/system-requirements.sh
# ==============================================================================

set -euo pipefail
# set +e           # Uncomment if you want the script to continue on failures
# set -x           # Uncomment for debug tracing

# ==============================================================================
# GLOBAL ARRAYS TO COLLECT RESULTS
# ==============================================================================
declare -a passed_items
declare -a failed_items

# ==============================================================================
# TEST DEFINITIONS
# Each entry corresponds to a numbered test description.
# ==============================================================================
TEST_DESCRIPTIONS=(
  "Required CPU architecture for Kubernetes components"
  "Minimum kernel version required for compatibility"
  "Supported OS version for stability and patching"
  "etcd must be running to store cluster state"
  "eBPF required for networking, monitoring, and security"
  "Required for Kubernetes networking and firewall rules"
  "Overlay networks and routing features require these kernel modules"
  "Needed for advanced network policy enforcement"
  "Required for encrypted pod-to-pod communications"
  "Needed for bandwidth management features"
  "Required for virtualized network interfaces"
)

# ==============================================================================
# TEST FUNCTIONS
# Each function emits lines of the form "[PASS] Description" or "[FAIL] Description"
# ==============================================================================
version_ge() {
  # Compare semantic versions: returns success if $1 >= $2
  printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1 | grep -qx "$2"
}

check_architecture() {
  local arch=$(uname -m)
  case "$arch" in
    x86_64) arch="AMD64" ;;
    aarch64) arch="AArch64" ;;
  esac
  if [[ "$arch" == "AMD64" || "$arch" == "AArch64" ]]; then
    echo "[PASS] Architecture: $arch"
  else
    echo "[FAIL] Architecture: $arch"
  fi
}

check_kernel() {
  local full=$(uname -r)
  local base=${full%%-*}
  if version_ge "$base" "5.10" || version_ge "$base" "4.18"; then
    echo "[PASS] Kernel: $full"
  else
    echo "[FAIL] Kernel: $full"
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" && $(version_ge "$VERSION_ID" "20.04") ]]; then
      echo "[PASS] OS: $NAME $VERSION_ID"
    else
      echo "[FAIL] OS: $NAME ${VERSION_ID:-Unknown}"
    fi
  else
    echo "[FAIL] OS: Unknown"
  fi
}

check_etcd() {
  if ! command -v kubectl &>/dev/null; then
    echo "[FAIL] etcd: kubectl not found"
    return
  fi
  local count=$(kubectl get pods -n kube-system -l component=etcd \
    2>/dev/null | awk 'NR>1 && $3=="Running"{c++} END{print c+0}')
  if [[ "$count" -ge 1 ]]; then
    echo "[PASS] etcd"
  else
    echo "[FAIL] etcd"
  fi
}

get_config_file() {
  if [[ -f /proc/config.gz ]]; then
    echo "/proc/config.gz"
  elif [[ -f /boot/config-$(uname -r) ]]; then
    echo "/boot/config-$(uname -r)"
  else
    echo ""
  fi
}

# Generic group tester for lists of CONFIG_* options
test_config_group() {
  local group_name="$1"; shift
  local cfg_file=$(get_config_file)
  for opt in "$@"; do
    local val
    if [[ "$cfg_file" == *.gz ]]; then
      val=$(zgrep -E "^$opt=(y|m)" "$cfg_file" | head -n1 || true)
    else
      val=$(grep -E "^$opt=(y|m)" "$cfg_file" | head -n1 || true)
    fi
    if [[ -n $val ]]; then
      echo "[PASS] $val"
    else
      echo "[FAIL] $opt"
    fi
  done
}

test_base_requirements() {
  test_config_group "eBPF Base" \
    CONFIG_BPF CONFIG_BPF_SYSCALL CONFIG_NET_CLS_BPF CONFIG_BPF_JIT \
    CONFIG_NET_CLS_ACT CONFIG_NET_SCH_INGRESS CONFIG_CRYPTO_SHA1 \
    CONFIG_CRYPTO_USER_API_HASH CONFIG_CGROUPS CONFIG_CGROUP_BPF \
    CONFIG_PERF_EVENTS CONFIG_SCHEDSTATS
}

test_iptables_masquerading() {
  test_config_group "Iptables Masquerade" \
    CONFIG_NETFILTER_XT_SET CONFIG_IP_SET CONFIG_IP_SET_HASH_IP \
    CONFIG_NETFILTER_XT_MATCH_COMMENT
}

test_tunneling_routing() {
  test_config_group "Tunneling & Routing" \
    CONFIG_VXLAN CONFIG_GENEVE CONFIG_FIB_RULES
}

test_l7_policies() {
  test_config_group "L7/FQDN Policies" \
    CONFIG_NETFILTER_XT_TARGET_TPROXY CONFIG_NETFILTER_XT_TARGET_MARK \
    CONFIG_NETFILTER_XT_TARGET_CT CONFIG_NETFILTER_XT_MATCH_MARK \
    CONFIG_NETFILTER_XT_MATCH_SOCKET
}

test_ipsec_requirements() {
  test_config_group "IPsec" \
    CONFIG_XFRM CONFIG_XFRM_OFFLOAD CONFIG_XFRM_STATISTICS CONFIG_XFRM_ALGO \
    CONFIG_XFRM_USER CONFIG_INET_ESP CONFIG_INET6_ESP CONFIG_INET_IPCOMP \
    CONFIG_INET6_IPCOMP CONFIG_INET_XFRM_TUNNEL CONFIG_INET6_XFRM_TUNNEL \
    CONFIG_INET_TUNNEL CONFIG_INET6_TUNNEL CONFIG_INET_XFRM_MODE_TUNNEL \
    CONFIG_CRYPTO_AEAD CONFIG_CRYPTO_AEAD2 CONFIG_CRYPTO_GCM \
    CONFIG_CRYPTO_SEQIV CONFIG_CRYPTO_CBC CONFIG_CRYPTO_HMAC \
    CONFIG_CRYPTO_SHA256 CONFIG_CRYPTO_AES
}

test_bandwidth_manager() {
  test_config_group "Bandwidth Manager" CONFIG_NET_SCH_FQ
}

test_netkit_mode() {
  test_config_group "Netkit Mode" CONFIG_NETKIT
}

# ==============================================================================
# RUN TESTS IN ORDER AND COLLECT RESULTS
# ==============================================================================
run_group() {
  local idx=$1
  local func=$2
  while IFS= read -r line; do
    # strip prefix [PASS] or [FAIL]
    local status=${line%%]*}"]
    local desc=${line#*] }
    if [[ $status == "[PASS]" ]]; then
      passed_items+=("$idx|$desc")
    else
      failed_items+=("$idx|$desc")
    fi
  done < <("$func")
}

# Print Test Details
echo "Test Details"
for i in "${!TEST_DESCRIPTIONS[@]}"; do
  printf "[Test %d] - %s\n" $((i+1)) "${TEST_DESCRIPTIONS[i]}"
done
echo

# Execute each test function
run_group 1 check_architecture
run_group 2 check_kernel
run_group 3 check_os
run_group 4 check_etcd
run_group 5 test_base_requirements
run_group 6 test_iptables_masquerading
run_group 7 test_tunneling_routing
run_group 8 test_l7_policies
run_group 9 test_ipsec_requirements
run_group 10 test_bandwidth_manager
run_group 11 test_netkit_mode

# ==============================================================================
# OUTPUT RESULTS
# ==============================================================================
echo "Results"
echo
printf "[ PASSED ] x%d\n" "${#passed_items[@]}"
for entry in "${passed_items[@]}"; do
  IFS='|' read -r num name <<< "$entry"
  printf "[PASS] - [Test %s] - %s\n" "$num" "$name"
done

printf "[ FAILED ] x%d\n" "${#failed_items[@]}"
for entry in "${failed_items[@]}"; do
  IFS='|' read -r num name <<< "$entry"
  printf "[FAIL] - [Test %s] - %s\n" "$num" "$name"
done

# ==============================================================================
# SUMMARY
# ==============================================================================
echo
echo "Summary"
echo
printf "PASSED = %d\n\n" "${#passed_items[@]}"
printf "FAILED = %d\n" "${#failed_items[@]}"
if (( ${#failed_items[@]} > 0 )); then
  echo
  echo "Failed Tests:"
  for entry in "${failed_items[@]}"; do
    IFS='|' read -r num name <<< "$entry"
    printf "[Test %s] - %s\n" "$num" "$name"
  done
fi

exit $(( ${#failed_items[@]} > 0 ))
