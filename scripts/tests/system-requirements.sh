#!/usr/bin/env bash


# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
# Filename:   system-requirements.sh
# Purpose:    Checks host compatibility for Cilium system requirements.
# Author:     Your Name
# Date:       2025-11-09
# Version:    1.0.0
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
  # Use kubectl to check etcd pods in Running state
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
