#!/usr/bin/env bash

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
# Filename:   system-requirements.sh
# Purpose:    Checks host compatibility for Cilium system requirements.
# Author:     Your Name
# Date:       2025-11-09
# Version:    1.0.0
# License:    MIT

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
# SPECIFIC CHECKS
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
    check_requirement "OS: $NAME $VERSION_ID" \
      "[[ \"$ID\" == \"ubuntu\" && version_ge \"$VERSION_ID\" \"20.04\" ]]"
  else
    echo "[FAIL] OS: Unknown (requires Ubuntu >=20.04)"
    return 1
  fi
}

check_etcd() {
  if command -v etcd &>/dev/null; then
    local ver
    ver=$(etcd --version 2>&1 | grep -Eo 'etcd Version: v?([0-9]+\.[0-9]+\.[0-9]+)' | awk '{print $3}')
    check_requirement "etcd: $ver" \
      "version_ge \"$ver\" \"3.1.0\""
  else
    echo "[FAIL] etcd: not found"
    return 1
  fi
}

# ==============================================================================
# MAIN EXECUTION & DEMONSTRATION
# ==============================================================================
echo "--- Demonstration of System Requirements Checks ---"
echo

declare -i failures=0

echo -e "\n[TEST A] Architecture"
check_architecture || ((failures++))

echo -e "\n[TEST B] Kernel"
check_kernel || ((failures++))

echo -e "\n[TEST C] OS Version"
check_os || ((failures++))

echo -e "\n[TEST D] etcd"
check_etcd || ((failures++))

# ==============================================================================
# SUMMARY OUTPUT AND FINAL EXIT
# ==============================================================================
echo -e "\n--- Summary ---"
if [ $failures -eq 0 ]; then
  echo "[PASS] All checks passed"
  exit 0
else
  echo "[FAIL] $failures check(s) failed"
  exit 1
fi
