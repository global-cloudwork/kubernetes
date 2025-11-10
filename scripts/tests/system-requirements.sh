# !/usr/bin/env bash
#
# curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/system-requirements.sh | bash
# system-requirements.sh
# Checks host compatibility for Cilium system requirements.

set -e

# Utility: compare semver versions (version_ge <version> <required>)
version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1 | grep -qx "$2"
}

echo "Checking Cilium System Requirements..."
echo

# 1. Architecture
arch=$(uname -m)
case "$arch" in
  x86_64) arch_name="AMD64"; arch_ok=0 ;;
  aarch64) arch_name="AArch64"; arch_ok=0 ;;
  *) arch_name="$arch"; arch_ok=1 ;;
esac
if [ $arch_ok -eq 0 ]; then
  echo "[PASS] Architecture: $arch_name"
else
  echo "[FAIL] Architecture: $arch_name"
fi

# 2. Linux kernel
kernel_full=$(uname -r)
kernel_base=${kernel_full%%-*}
if version_ge "$kernel_base" "5.10" || version_ge "$kernel_base" "4.18"; then
  kernel_ok=0
  echo "[PASS] Kernel: $kernel_full"
else
  kernel_ok=1
  echo "[FAIL] Kernel: $kernel_full (requires >=5.10 or >=4.18)"
fi

# 4. etcd
if command -v etcd &>/dev/null; then
  etcd_ver=$(etcd --version 2>&1 | grep -Eo 'etcd Version: v?([0-9]+\.[0-9]+\.[0-9]+)' | awk '{print $3}')
  if version_ge "$etcd_ver" "3.1.0"; then
    etcd_ok=0
    echo "[PASS] etcd: $etcd_ver"
  else
    etcd_ok=1
    echo "[FAIL] etcd: $etcd_ver (requires >=3.1.0)"
  fi
else
  etcd_ok=1
  echo "[FAIL] etcd: not found"
fi

# Summary
echo
echo "Test Summary:"
declare -a passed=()
declare -a failed=()

if [ $arch_ok -eq 0 ]; then passed+=("Architecture"); else failed+=("Architecture"); fi
if [ $kernel_ok -eq 0 ]; then passed+=("Kernel"); else failed+=("Kernel"); fi
if [ $etcd_ok -eq 0 ]; then passed+=("etcd"); else failed+=("etcd"); fi

if [ ${#failed[@]} -eq 0 ]; then
  echo "[PASS] All checks passed: ${passed[*]}"
  exit 0
else
  echo "[PASS] Passed: ${passed[*]}"
  echo "[FAIL] Failed: ${failed[*]}"
  exit 1
fi
