#!/usr/bin/env bash
#
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
printf "Architecture: %s -> %s\n" "$arch" "$arch_ok" && \
  ( [ $arch_ok -eq 0 ] && echo "  PASS: Supported architecture ($arch_name)" || echo "  FAIL: Unsupported architecture ($arch_name)" )

# 2. Linux kernel
kernel_full=$(uname -r)
kernel_base=${kernel_full%%-*}
if version_ge "$kernel_base" "5.10" || version_ge "$kernel_base" "4.18"; then
  kernel_ok=0
  echo "Kernel: $kernel_full -> PASS (>= 5.10 or >= 4.18)"
else
  kernel_ok=1
  echo "Kernel: $kernel_full -> FAIL (requires >=5.10 or >=4.18)"
fi

# 3. clang+LLVM
if command -v clang &>/dev/null; then
  clang_ver=$(clang --version | head -n1 | sed -E 's/.*version ([0-9]+\.[0-9]+).*/\1/')
  if version_ge "$clang_ver" "18.1"; then
    clang_ok=0
    echo "clang+LLVM: $clang_ver -> PASS (>=18.1)"
  else
    clang_ok=1
    echo "clang+LLVM: $clang_ver -> FAIL (requires >=18.1)"
  fi
else
  clang_ok=1
  echo "clang+LLVM: not found -> FAIL"
fi

# 4. etcd
if command -v etcd &>/dev/null; then
  etcd_ver=$(etcd --version 2>&1 | grep -Eo 'etcd Version: v?([0-9]+\.[0-9]+\.[0-9]+)' | awk '{print $3}')
  if version_ge "$etcd_ver" "3.1.0"; then
    etcd_ok=0
    echo "etcd: $etcd_ver -> PASS (>=3.1.0)"
  else
    etcd_ok=1
    echo "etcd: $etcd_ver -> FAIL (requires >=3.1.0)"
  fi
else
  etcd_ok=1
  echo "etcd: not found -> FAIL"
fi

# Summary
echo
echo "Summary of checks:"
declare -A results=(
  ["Architecture"]=$arch_ok
  ["Kernel"]=$kernel_ok
  ["clang+LLVM"]=$clang_ok
  ["etcd"]=$etcd_ok
)

all_ok=0
for name in "${!results[@]}"; do
  if [ "${results[$name]}" -ne 0 ]; then
    all_ok=1
    printf "- %s: FAIL\n" "$name"
  else
    printf "- %s: PASS\n" "$name"
  fi
done

if [ $all_ok -eq 0 ]; then
  echo
  echo "All checks passed. System meets Cilium requirements."
  exit 0
else
  echo
  echo "Some checks failed. Please address the above failures."
  exit 1
fi
