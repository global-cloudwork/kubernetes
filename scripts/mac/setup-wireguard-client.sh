#!/usr/bin/env bash
set -euo pipefail

# Mac WireGuard Client Setup Helper
# Generates Mac client keypair and coordinates with cloud post-provisioning

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
CLOUD_SCRIPTS="${PROJECT_ROOT}/scripts/cloud"
ENV_FILE="${PROJECT_ROOT}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Mac WireGuard Client Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo "==> Checking prerequisites..."

if ! command -v wg &> /dev/null; then
  echo -e "${YELLOW}⚠ WireGuard command-line tools not found${NC}"
  echo "  Install via: brew install wireguard-tools"
  exit 1
fi
echo -e "${GREEN}✓ WireGuard tools installed${NC}"

if [ ! -d "/Applications/WireGuard.app" ]; then
  echo -e "${YELLOW}⚠ WireGuard.app not found in /Applications${NC}"
  echo "  Install from: https://apps.apple.com/us/app/wireguard/id1451685025"
  exit 1
fi
echo -e "${GREEN}✓ WireGuard app installed${NC}"

if [ ! -f "${ENV_FILE}" ]; then
  echo -e "${RED}✗ .env file not found at ${ENV_FILE}${NC}"
  exit 1
fi
echo -e "${GREEN}✓ .env file found${NC}"

echo ""
echo "==> Generating Mac WireGuard keypair..."

# Use a timestamped directory for this setup
SETUP_DIR="${PROJECT_ROOT}/wireguard-client-setup-$(date +%s)"
mkdir -p "${SETUP_DIR}"

MAC_PRIVATE_KEY_FILE="${SETUP_DIR}/mac-private.key"
MAC_PUBLIC_KEY_FILE="${SETUP_DIR}/mac-public.key"

if [ -f "${MAC_PRIVATE_KEY_FILE}" ]; then
  echo -e "${YELLOW}⚠ Keypair already exists at ${SETUP_DIR}${NC}"
  read -p "  Use existing keys? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "  Generating new keypair..."
    wg genkey | tee "${MAC_PRIVATE_KEY_FILE}" | wg pubkey > "${MAC_PUBLIC_KEY_FILE}"
  fi
else
  wg genkey | tee "${MAC_PRIVATE_KEY_FILE}" | wg pubkey > "${MAC_PUBLIC_KEY_FILE}"
fi

MAC_PUBLIC_KEY=$(cat "${MAC_PUBLIC_KEY_FILE}")
echo -e "${GREEN}✓ Keypair generated${NC}"
echo "  Private key: ${MAC_PRIVATE_KEY_FILE}"
echo "  Public key:  ${MAC_PUBLIC_KEY_FILE}"
echo ""

# Run post-provisioning with Mac public key
echo "==> Running cloud post-provisioning script..."
echo "  This will:"
echo "    1. Retrieve server public key from GCP instance"
echo "    2. Add your Mac as a WireGuard peer"
echo "    3. Generate client configuration"
echo ""

export MAC_CLIENT_PUBKEY="${MAC_PUBLIC_KEY}"

if [ ! -f "${CLOUD_SCRIPTS}/post-provision-cloud-machine.sh" ]; then
  echo -e "${RED}✗ Post-provisioning script not found${NC}"
  echo "  Expected: ${CLOUD_SCRIPTS}/post-provision-cloud-machine.sh"
  exit 1
fi

cd "${CLOUD_SCRIPTS}"
bash ./post-provision-cloud-machine.sh

# Find the generated config
CONFIG_FILE=$(ls -t mac-wg0-*.conf 2>/dev/null | head -1)

if [ -z "${CONFIG_FILE}" ]; then
  echo -e "${YELLOW}⚠ Could not find generated config file${NC}"
  CONFIG_FILE="${SETUP_DIR}/mac-wg0.conf"
  echo "  Expected config file: ${CONFIG_FILE}"
fi

echo ""
echo "==> Finalizing client configuration..."

# Read private key and add to config
PRIVATE_KEY_CONTENT=$(cat "${MAC_PRIVATE_KEY_FILE}")

# If config file was generated in cloud scripts dir, copy it and update
if [ -f "${CONFIG_FILE}" ] && [ "${CONFIG_FILE}" != "${SETUP_DIR}/mac-wg0.conf" ]; then
  cp "${CONFIG_FILE}" "${SETUP_DIR}/mac-wg0.conf"
  CONFIG_FILE="${SETUP_DIR}/mac-wg0.conf"
fi

# Create/update config with private key
if [ -f "${CONFIG_FILE}" ]; then
  # Replace placeholder with actual private key
  sed -i '' "s|PrivateKey = <YOUR_MAC_PRIVATE_KEY_HERE>|PrivateKey = ${PRIVATE_KEY_CONTENT}|" "${CONFIG_FILE}"

  # Verify config is valid
  if ! wg-quick strip "${CONFIG_FILE}" > /dev/null 2>&1; then
    echo -e "${RED}✗ Generated config is invalid${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Configuration file ready${NC}"
  echo "  Config: ${CONFIG_FILE}"
else
  echo -e "${YELLOW}⚠ Could not auto-generate config${NC}"
  echo "  Manual steps needed (see instructions below)"
fi

echo ""
echo "=== ${GREEN}SETUP COMPLETE${NC} ==="
echo ""
echo "Your Mac WireGuard setup files:"
echo "  Setup directory: ${SETUP_DIR}"
echo "  Private key:     ${MAC_PRIVATE_KEY_FILE}"
echo "  Public key:      ${MAC_PUBLIC_KEY_FILE}"
echo "  Config:          ${CONFIG_FILE}"
echo ""
echo "NEXT STEPS:"
echo "  1. Open WireGuard app on Mac"
echo "  2. Click '+' → 'Import Tunnel(s) from File'"
echo "  3. Select: ${CONFIG_FILE}"
echo "  4. Click 'Connect'"
echo "  5. Test connectivity:"
echo "     ping 10.20.0.1           (gateway)"
echo "     ping 192.168.1.10        (n8n)"
echo "     curl https://vpn-gateway.local/n8n"
echo ""
echo "SECURITY NOTES:"
echo "  • Keep ${MAC_PRIVATE_KEY_FILE} private"
echo "  • Do not commit to Git"
echo "  • Delete after importing into WireGuard"
echo ""
echo "To reconnect after server reboot:"
echo "  bash ${SCRIPT_DIR}/setup-wireguard-client.sh"
echo ""
echo "=== ${BLUE}Setup directory will be kept for reference${NC} ==="
