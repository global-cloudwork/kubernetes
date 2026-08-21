#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from root .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"

if [ -f "${ENV_FILE}" ]; then
  set +u  # Disable unset check for sourcing .env
  source "${ENV_FILE}"
  set -u
else
  echo "Warning: .env file not found at ${ENV_FILE}"
  echo "Set GCP_PROJECT_ID, GCP_ZONE environment variables manually"
fi

# Post-Boot Configuration: Retrieve WireGuard keys, add peer clients, validate tunnel
# Runs after GCP instance boot + cloud-machine-init.sh completion

# Environment & Context
PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID environment variable}"
ZONE="${GCP_ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-gce-vpn-gateway}"

# WireGuard Configuration (must match cloud-machine-init.sh)
WG_SUBNET="${WG_NET:-10.20.0.0/24}"
LOCAL_LAN_SUBNET="${LOCAL_LAN_SUBNET:-192.168.1.0/24}"
LAPTOP_PEER_IP="${LAPTOP_PEER_IP:-10.20.0.3/32}"

# Output directory for peer configs
CONFIG_OUTPUT_DIR="${CONFIG_OUTPUT_DIR:-.}"
TIMESTAMP=$(date +%s)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "==> Waiting for instance to boot and initialize WireGuard..."
WAIT_COUNT=0
MAX_WAIT=60  # 5 minutes (60 * 5 second intervals)

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --tunnel-through-iap -- "test -f /tmp/wg0-public.key" 2>/dev/null; then
    echo -e "${GREEN}✓ Instance ready${NC}"
    break
  fi
  WAIT_COUNT=$((WAIT_COUNT + 1))
  if [ $((WAIT_COUNT % 4)) -eq 0 ]; then
    echo "  Still waiting... ($((WAIT_COUNT * 5))s elapsed)"
  fi
  sleep 5
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  echo -e "${RED}✗ Timeout waiting for instance boot (5 minutes)${NC}"
  exit 1
fi

echo ""
echo "==> Retrieving server WireGuard public key..."
SERVER_PUB_KEY=$(gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --tunnel-through-iap -- \
  "cat /tmp/wg0-public.key" 2>/dev/null)

if [ -z "${SERVER_PUB_KEY}" ]; then
  echo -e "${RED}✗ Failed to retrieve server public key${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Server Public Key: ${SERVER_PUB_KEY}${NC}"

echo ""
echo "==> Retrieving current WireGuard interface configuration..."
STATIC_IP=$(gcloud compute addresses describe "vpn-gateway-static-ip" \
  --region="us-central1" --format="value(address)" 2>/dev/null)

if [ -z "${STATIC_IP}" ]; then
  echo -e "${RED}✗ Failed to retrieve static IP${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Gateway Static IP: ${STATIC_IP}${NC}"

echo ""
echo "==> Generating client WireGuard configurations..."

# Prompt for Mac client public key (or use environment variable)
if [ -z "${MAC_CLIENT_PUBKEY:-}" ]; then
  echo ""
  echo -e "${YELLOW}⚠ Mac client public key not provided${NC}"
  echo "  To add Mac client peer, provide MAC_CLIENT_PUBKEY environment variable:"
  echo "  export MAC_CLIENT_PUBKEY=\"<your-mac-public-key>\""
  echo "  Then run: ./post-provision-cloud-machine.sh"
  echo ""
  echo "  OR generate Mac client keypair locally:"
  echo "    wg genkey | tee mac-private.key | wg pubkey > mac-public.key"
  echo ""
else
  echo "==> Adding Mac client as WireGuard peer..."

  # Create peer config for server
  PEER_CONFIG="[Peer]
PublicKey = ${MAC_CLIENT_PUBKEY}
AllowedIPs = ${LAPTOP_PEER_IP}"

  # Add peer to running WireGuard config via SSH
  gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --tunnel-through-iap -- \
    "sudo wg set wg0 peer ${MAC_CLIENT_PUBKEY} allowed-ips ${LAPTOP_PEER_IP}" 2>/dev/null

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Mac client peer added to WireGuard${NC}"
  else
    echo -e "${RED}✗ Failed to add Mac client peer${NC}"
    exit 1
  fi

  # Generate client config file
  MAC_CONFIG_FILE="${CONFIG_OUTPUT_DIR}/mac-wg0-${TIMESTAMP}.conf"
  cat > "${MAC_CONFIG_FILE}" <<EOF
[Interface]
Address = ${LAPTOP_PEER_IP}
PrivateKey = <YOUR_MAC_PRIVATE_KEY_HERE>
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = ${STATIC_IP}:51820
AllowedIPs = ${WG_SUBNET}, ${LOCAL_LAN_SUBNET}
PersistentKeepalive = 25
EOF

  chmod 600 "${MAC_CONFIG_FILE}"
  echo -e "${GREEN}✓ Mac client config saved to: ${MAC_CONFIG_FILE}${NC}"
fi

echo ""
echo "==> Validating WireGuard tunnel connectivity..."

# Check WireGuard interface status on server
WG_STATUS=$(gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --tunnel-through-iap -- \
  "sudo wg show wg0" 2>/dev/null)

if echo "${WG_STATUS}" | grep -q "interface: wg0"; then
  echo -e "${GREEN}✓ WireGuard interface active on server${NC}"
else
  echo -e "${YELLOW}⚠ Could not verify WireGuard interface status${NC}"
fi

# Test ICMP through overlay (requires at least one peer connected)
echo ""
echo "==> Performing network diagnostics..."

# Get instance details
INSTANCE_INFO=$(gcloud compute instances describe "${VM_NAME}" --zone="${ZONE}" \
  --format="value(networkInterfaces[0].networkIP)")

echo "Gateway Internal IP: ${INSTANCE_INFO}"
echo "Gateway Public IP:   ${STATIC_IP}"
echo "WireGuard Subnet:    ${WG_SUBNET}"
echo "Local LAN Subnet:    ${LOCAL_LAN_SUBNET}"

echo ""
echo "=================================================================="
echo " POST-BOOT PROVISIONING COMPLETE"
echo "=================================================================="
echo ""
echo "SERVER DETAILS:"
echo "  Public IP       : ${STATIC_IP}:51820"
echo "  WireGuard Key   : ${SERVER_PUB_KEY}"
echo ""
echo "MAC CLIENT CONFIG:"
if [ ! -z "${MAC_CLIENT_PUBKEY:-}" ]; then
  echo "  Config File     : ${MAC_CONFIG_FILE}"
  echo "  Peer IP         : ${LAPTOP_PEER_IP}"
  echo "  DNS             : 1.1.1.1"
  echo ""
  echo "NEXT STEPS:"
  echo "  1. Retrieve your Mac private key and add to: ${MAC_CONFIG_FILE}"
  echo "  2. Import ${MAC_CONFIG_FILE} into Mac WireGuard app"
  echo "  3. Enable connection"
  echo "  4. Test: ping 192.168.1.10 (n8n), etc."
else
  echo "  Status          : Not configured (no MAC_CLIENT_PUBKEY provided)"
  echo ""
  echo "TO ADD MAC CLIENT:"
  echo "  1. Generate Mac keypair:"
  echo "     wg genkey | tee mac-private.key | wg pubkey > mac-public.key"
  echo ""
  echo "  2. Run post-provision script with key:"
  echo "     export MAC_CLIENT_PUBKEY=\$(cat mac-public.key)"
  echo "     ./post-provision-cloud-machine.sh"
fi

echo ""
echo "SSH ACCESS (via IAP):"
echo "  gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap"
echo ""
echo "=================================================================="
