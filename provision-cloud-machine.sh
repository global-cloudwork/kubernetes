#!/usr/bin/env bash
set -euo pipefail

# Environment & Context
PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID environment variable}"
REGION="${GCP_REGION:-us-central1}"
ZONE="${GCP_ZONE:-us-central1-a}"

# Startup Script
STARTUP_SCRIPT_PATH="${STARTUP_SCRIPT_PATH:-.\/cloud-machine-init.sh}"

VPC_NAME="vpn-gateway-vpc"
SUBNET_NAME="vpn-gateway-subnet"
SUBNET_CIDR="10.100.0.0/24"
STATIC_IP_NAME="vpn-gateway-static-ip"
SA_NAME="gce-vpn-gateway-sa"
VM_NAME="gce-vpn-gateway"

# Caddy Configuration (optional - can be overridden)
CADDY_DOMAIN="${CADDY_DOMAIN:-vpn-gateway.local}"

echo "==> Validating startup script exists..."
if [ ! -f "${STARTUP_SCRIPT_PATH}" ]; then
  echo "Error: Startup script not found at ${STARTUP_SCRIPT_PATH}"
  exit 1
fi

echo "==> Setting active GCP Project context..."
gcloud config set project "${PROJECT_ID}" --quiet

echo "==> Provisioning Minimal IAM Service Account..."
if ! gcloud iam service-accounts describe "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" &>/dev/null; then
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="VPN Gateway Minimal SA"
fi
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Bind strictly necessary operational roles
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter" --quiet >/dev/null

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.metricWriter" --quiet >/dev/null

echo "==> Provisioning VPC Network & Subnet..."
if ! gcloud compute networks describe "${VPC_NAME}" &>/dev/null; then
  gcloud compute networks create "${VPC_NAME}" --subnet-mode=custom
fi

if ! gcloud compute networks subnets describe "${SUBNET_NAME}" --region="${REGION}" &>/dev/null; then
  gcloud compute networks subnets create "${SUBNET_NAME}" \
    --network="${VPC_NAME}" \
    --region="${REGION}" \
    --range="${SUBNET_CIDR}"
fi

echo "==> Reserving Static External IPv4..."
if ! gcloud compute addresses describe "${STATIC_IP_NAME}" --region="${REGION}" &>/dev/null; then
  gcloud compute addresses create "${STATIC_IP_NAME}" --region="${REGION}"
fi
STATIC_IP=$(gcloud compute addresses describe "${STATIC_IP_NAME}" --region="${REGION}" --format="value(address)")

echo "==> Applying VPC Firewall Boundary Rules..."
# Allow WireGuard UDP Inbound
if ! gcloud compute firewall-rules describe "allow-wireguard-ingress" &>/dev/null; then
  gcloud compute firewall-rules create "allow-wireguard-ingress" \
    --network="${VPC_NAME}" \
    --allow=udp:51820 \
    --source-ranges="0.0.0.0/0" \
    --target-tags="vpn-gateway"
fi

# Allow SSH ONLY via GCP Identity-Aware Proxy (IAP) CIDR
if ! gcloud compute firewall-rules describe "allow-iap-ssh" &>/dev/null; then
  gcloud compute firewall-rules create "allow-iap-ssh" \
    --network="${VPC_NAME}" \
    --allow=tcp:22 \
    --source-ranges="35.235.240.0/20" \
    --target-tags="vpn-gateway"
fi

echo "==> Deploying Hardened Alpine WireGuard Gateway Instance..."
if ! gcloud compute instances describe "${VM_NAME}" --zone="${ZONE}" &>/dev/null; then
  gcloud compute instances create "${VM_NAME}" \
    --zone="${ZONE}" \
    --machine-type="e2-micro" \
    --image-family="alpine-edge" \
    --image-project="alpine-linux-cloud" \
    --boot-disk-size="10GB" \
    --boot-disk-type="pd-standard" \
    --network="${VPC_NAME}" \
    --subnet="${SUBNET_NAME}" \
    --address="${STATIC_IP}" \
    --service-account="${SA_EMAIL}" \
    --scopes="cloud-platform" \
    --tags="vpn-gateway" \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --metadata=enable-oslogin=TRUE,block-project-wide-ssh-keys=TRUE \
    --metadata-from-file=user-data="${STARTUP_SCRIPT_PATH}"
fi

echo ""
echo "=================================================================="
echo " INFRASTRUCTURE READY"
echo " Target Static IP: ${STATIC_IP}"
echo " Instance Name   : ${VM_NAME}"
echo " Zone            : ${ZONE}"
echo ""
echo " NEXT STEPS:"
echo "  1. Wait 2-3 minutes for instance boot and WireGuard initialization"
echo "  2. Run post-boot automation: ./post-provision-cloud-machine.sh"
echo ""
echo " MANUAL SSH ACCESS (if needed):"
echo "  gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap"
echo "=================================================================="