#!/bin/bash

# ===============================================
# Cilium/WireGuard Kernel Dependency Diagnostics
# This script checks for common issues related to kernel configuration
# that block IPsec/WireGuard tunnel features (like CONFIG_INET_XFRM_MODE_TUNNEL).
# ===============================================

KERNEL_VERSION=$(uname -r)
KERNEL_CONFIG_PATH="/boot/config-${KERNEL_VERSION}"

echo "--- 1. KERNEL VERSION CHECK (Relates to Reason #2: Outdated Kernel) ---"
echo "Current Kernel Version: ${KERNEL_VERSION}"
# Note: WireGuard is in-tree starting kernel 5.6. Cilium recommends 5.10+.
if (( $(echo ${KERNEL_VERSION} | cut -d. -f1) >= 5 && $(echo ${KERNEL_VERSION} | cut -d. -f2) >= 10 )); then
    echo "Result: PASS. Kernel is modern enough for most Cilium/WireGuard features."
elif (( $(echo ${KERNEL_VERSION} | cut -d. -f1) >= 5 && $(echo ${KERNEL_VERSION} | cut -d. -f2) >= 6 )); then
    echo "Result: WARNING. WireGuard is supported, but Cilium may prefer 5.10+."
else
    echo "Result: FAIL. Kernel is potentially too old. Upgrade highly recommended."
fi
echo ""

echo "--- 2. REQUIRED KERNEL CONFIG CHECK (Relates to Reason #1 & #3: Missing Config) ---"
if [ -f "${KERNEL_CONFIG_PATH}" ]; then
    echo "Checking kernel config file: ${KERNEL_CONFIG_PATH}"
    
    # 2a. Check for the problematic XFRM tunnel mode config
    XFRM_MODE_TUNNEL=$(grep "CONFIG_INET_XFRM_MODE_TUNNEL" "${KERNEL_CONFIG_PATH}" 2>/dev/null)
    echo "CONFIG_INET_XFRM_MODE_TUNNEL: ${XFRM_MODE_TUNNEL:-NOT FOUND}"
    if [[ "${XFRM_MODE_TUNNEL}" == *"is not set"* ]]; then
        echo "Diagnosis: FAIL. This config is permanently disabled in the kernel build."
    elif [[ "${XFRM_MODE_TUNNEL}" == *"=m"* ]]; then
        echo "Diagnosis: WARNING. Config is a module. Need to ensure it is loaded."
    else
        echo "Diagnosis: PASS. Config is built-in or set to 'y'."
    fi

    echo "---"

    # 2b. Check for the main WireGuard config
    WIREGUARD_CONFIG=$(grep "CONFIG_WIREGUARD" "${KERNEL_CONFIG_PATH}" 2>/dev/null)
    echo "CONFIG_WIREGUARD: ${WIREGUARD_CONFIG:-NOT FOUND}"
    if [[ "${WIREGUARD_CONFIG}" == *"is not set"* ]]; then
        echo "Diagnosis: FAIL. WireGuard is not compiled into the kernel."
    else
        echo "Diagnosis: PASS. WireGuard appears configured."
    fi
else
    echo "WARNING: Kernel config file not found at ${KERNEL_CONFIG_PATH}. Cannot verify build options directly."
fi
echo ""

echo "--- 3. MODULE LOAD CHECK (Relates to Reason #1: Missing Module Load) ---"

# Check for the XFRM tunnel module
XFRM_MODULE=$(lsmod | grep xfrm_mode_tunnel)
if [ -z "${XFRM_MODULE}" ]; then
    echo "xfrm4_mode_tunnel is NOT currently loaded."
    echo "Attempting to load module (if available in kernel):"
    sudo modprobe xfrm4_mode_tunnel 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "SUCCESS: xfrm4_mode_tunnel loaded. Rerun Cilium test."
    else
        echo "FAIL: Module loading failed. This indicates the module may be missing from your kernel image."
    fi
else
    echo "PASS: xfrm4_mode_tunnel is already loaded."
fi
echo "---"

# Check for the WireGuard module
WIREGUARD_MODULE=$(lsmod | grep wireguard)
if [ -z "${WIREGUARD_MODULE}" ]; then
    echo "wireguard is NOT currently loaded."
    echo "Attempting to load module (if available in kernel):"
    sudo modprobe wireguard 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "SUCCESS: wireguard loaded. Rerun Cilium test."
    else
        echo "FAIL: Module loading failed. If running a modern kernel, this suggests the config is missing (Reason #2/3)."
    fi
else
    echo "PASS: wireguard is already loaded."
fi
echo ""

echo "--- DIAGNOSTICS COMPLETE ---"
echo "Based on the results above, focus on fixing any FAIL or WARNING states."