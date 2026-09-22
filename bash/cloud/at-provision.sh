#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/../../.env}"

if [ -f "${ENV_FILE}" ]; then
  set +u  # Disable unset check for sourcing .env
  source "${ENV_FILE}"
  set -u
else
  echo "Warning: .env file not found at ${ENV_FILE}; using exported environment variables" >&2
fi

# Environment & Context
PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID environment variable}"
REGION="${GCP_REGION:-us-central1}"
ZONE="${GCP_ZONE:-us-central1-a}"
REPOSITORY_URL="${GIT_REPOSITORY_URL:-https://github.com/global-cloudwork/kubernetes.git}"
MACHINE_TYPE="${GCP_MACHINE_TYPE:-e2-medium}"

# Startup Script (default to at-boot.sh in same directory)
STARTUP_SCRIPT_PATH="${STARTUP_SCRIPT_PATH:-${SCRIPT_DIR}/at-boot.sh}"

VPC_NAME="${GCP_VPC_NAME:-kubernetes-vpc}"
SUBNET_NAME="${GCP_SUBNET_NAME:-kubernetes-subnet}"
SUBNET_CIDR="10.100.0.0/24"
STATIC_IP_NAME="${GCP_STATIC_IP_NAME:-kubernetes-static-ip}"
SA_NAME="${GCP_SERVICE_ACCOUNT_NAME:-gce-kubernetes-sa}"
VM_NAME="${GCP_VM_NAME:-gce-kubernetes}"

echo "==> Validating startup script exists..."
if [ ! -f "${STARTUP_SCRIPT_PATH}" ]; then
  echo "Error: Startup script not found at ${STARTUP_SCRIPT_PATH}"
  exit 1
fi

echo "==> Setting active GCP Project context..."
gcloud config set project "${PROJECT_ID}" --quiet

echo "==> Provisioning service account..."
if ! gcloud iam service-accounts describe "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" &>/dev/null; then
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="GCE Kubernetes bootstrap service account" \
    --quiet
fi
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Bind strictly necessary operational roles
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter" --quiet >/dev/null

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/monitoring.metricWriter" --quiet >/dev/null

# Keep the secret accessor grant bounded to the current bootstrap window. A
# stable condition title lets a rerun replace the previous window rather than
# accumulating IAM bindings.
SECRET_CONDITION_TITLE="kubernetes-bootstrap-secret-access"
gcloud projects remove-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor" \
  --condition="title=${SECRET_CONDITION_TITLE}" \
  --quiet >/dev/null 2>&1 || true
SECRET_ACCESS_EXPIRES="$(date -u -d '+24 hours' '+%Y-%m-%dT%H:%M:%SZ')"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor" \
  --condition="expression=request.time < timestamp('${SECRET_ACCESS_EXPIRES}'),title=${SECRET_CONDITION_TITLE},description=Temporary bootstrap secret access" \
  --quiet >/dev/null

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
if ! gcloud compute firewall-rules describe "allow-kubernetes-web" &>/dev/null; then
  gcloud compute firewall-rules create "allow-kubernetes-web" \
    --network="${VPC_NAME}" \
    --allow=tcp:80,tcp:443 \
    --source-ranges="0.0.0.0/0" \
    --target-tags="kubernetes-host"
fi

# Allow SSH ONLY via GCP Identity-Aware Proxy (IAP) CIDR
if ! gcloud compute firewall-rules describe "allow-iap-ssh" &>/dev/null; then
  gcloud compute firewall-rules create "allow-iap-ssh" \
    --network="${VPC_NAME}" \
    --allow=tcp:22 \
    --source-ranges="35.235.240.0/20" \
    --target-tags="kubernetes-host"
fi

echo "==> Replacing Ubuntu Kind Kubernetes host..."
if gcloud compute instances describe "${VM_NAME}" --zone="${ZONE}" &>/dev/null; then
  echo "    Removing the old instance and releasing its static address..."
  gcloud compute instances delete-access-config "${VM_NAME}" \
    --zone="${ZONE}" --access-config-name="external-nat" --quiet >/dev/null 2>&1 || true
  gcloud compute instances delete "${VM_NAME}" --zone="${ZONE}" --quiet
fi

gcloud compute instances create "${VM_NAME}" \
  --zone="${ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --image-family="ubuntu-2404-lts-amd64" \
  --image-project="ubuntu-os-cloud" \
  --boot-disk-size="30GB" \
  --boot-disk-type="pd-balanced" \
  --network="${VPC_NAME}" \
  --subnet="${SUBNET_NAME}" \
  --address="${STATIC_IP}" \
  --service-account="${SA_EMAIL}" \
  --scopes="cloud-platform" \
  --tags="kubernetes-host" \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --metadata="enable-oslogin=TRUE,block-project-wide-ssh-keys=TRUE,GIT_REPOSITORY_URL=${REPOSITORY_URL}" \
  --metadata-from-file="startup-script=${STARTUP_SCRIPT_PATH}" \
  --quiet

echo ""
echo "=================================================================="
echo " INFRASTRUCTURE READY"
echo " Target Static IP: ${STATIC_IP}"
echo " Instance Name   : ${VM_NAME}"
echo " Zone            : ${ZONE}"
echo ""
echo " NEXT STEPS:"
echo "  1. Wait for the startup script to finish"
echo "  2. Populate /root/kubernetes-secrets on the instance"
echo "  3. Log in and run: sudo /root/at-login.sh"
echo ""
echo " MANUAL SSH ACCESS (if needed):"
echo "  gcloud compute ssh ${VM_NAME} --zone=${ZONE} --tunnel-through-iap"
echo "=================================================================="
