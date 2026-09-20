#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
CLOUD_SCRIPTS="${PROJECT_ROOT}/bash/cloud"

readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly RESET='\033[0m'

echo_header() { printf '%b▶%b %s\n' "${BLUE}" "${RESET}" "$1"; }
echo_ok() { printf '%b✓%b %s\n' "${GREEN}" "${RESET}" "$1"; }
common_err() { printf '%b✗%b %s\n' "${RED}" "${RESET}" "$1" >&2; }

echo
echo_header "Mac WireGuard Client Setup"
echo

command -v wg &>/dev/null || { common_err "wg not found: brew install wireguard-tools"; exit 1; }
[ -d "/Applications/WireGuard.app" ] || { common_err "WireGuard.app not found"; exit 1; }
echo_ok "Prerequisites verified"

echo_header "Generating keypair..."
SETUP_DIR="${PROJECT_ROOT}/wireguard-client-setup-$(date +%s)"
mkdir -p "${SETUP_DIR}"

MAC_PRIVATE_KEY_FILE="${SETUP_DIR}/mac-private.key"
MAC_PUBLIC_KEY_FILE="${SETUP_DIR}/mac-public.key"

if [ -f "${MAC_PRIVATE_KEY_FILE}" ]; then
  read -r -p "Keypair exists; use existing? (y/n) " -n 1 REPLY
  printf '\n'
  [[ $REPLY =~ ^[Yy]$ ]] || {
    wg genkey | tee "${MAC_PRIVATE_KEY_FILE}" | wg pubkey > "${MAC_PUBLIC_KEY_FILE}"
  }
else
  wg genkey | tee "${MAC_PRIVATE_KEY_FILE}" | wg pubkey > "${MAC_PUBLIC_KEY_FILE}"
fi

MAC_PUBLIC_KEY=$(cat "${MAC_PUBLIC_KEY_FILE}")
echo_ok "Keypair ready"
echo "  Private: ${MAC_PRIVATE_KEY_FILE}"
echo "  Public:  ${MAC_PUBLIC_KEY_FILE}"
echo

[ -f "${CLOUD_SCRIPTS}/post-provision-cloud-machine.sh" ] || \
  { common_err "Post-provisioning script not found"; exit 1; }

echo_header "Running cloud post-provisioning..."
export MAC_CLIENT_PUBKEY="${MAC_PUBLIC_KEY}"
cd "${CLOUD_SCRIPTS}"
bash ./post-provision-cloud-machine.sh

CONFIG_FILE=$(ls -t mac-wg0-*.conf 2>/dev/null | head -1)
[ -z "${CONFIG_FILE}" ] && CONFIG_FILE="${SETUP_DIR}/mac-wg0.conf"

echo_header "Finalizing configuration..."
PRIVATE_KEY_CONTENT=$(cat "${MAC_PRIVATE_KEY_FILE}")

if [ -f "${CONFIG_FILE}" ] && [ "${CONFIG_FILE}" != "${SETUP_DIR}/mac-wg0.conf" ]; then
  cp "${CONFIG_FILE}" "${SETUP_DIR}/mac-wg0.conf"
  CONFIG_FILE="${SETUP_DIR}/mac-wg0.conf"
fi

if [ -f "${CONFIG_FILE}" ]; then
  sed -i '' "s|PrivateKey = <YOUR_MAC_PRIVATE_KEY_HERE>|PrivateKey = ${PRIVATE_KEY_CONTENT}|" "${CONFIG_FILE}"
  wg-quick strip "${CONFIG_FILE}" >/dev/null 2>&1 || { common_err "Config invalid"; exit 1; }
  echo_ok "Config ready: ${CONFIG_FILE}"
else
  common_err "Config not found; check post-provisioning output"
  exit 1
fi

echo
echo_ok "Setup complete"
echo "  Config: ${CONFIG_FILE}"
