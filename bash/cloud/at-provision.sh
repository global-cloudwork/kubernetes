#!/usr/bin/env bash
source ../../.env

STARTUP_SCRIPT_PATH="${SCRIPT_DIR}/at-boot.sh"
SA_EMAIL="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
NETWORK_TAG="kubernetes-host"
gcloud config set project "${GCP_PROJECT_ID}" --quiet

STATIC_IP="$(gcloud compute addresses describe "${GCP_STATIC_IP_NAME}" \
  --region="${GCP_REGION}" --format="value(address)")"
gcloud compute instances delete "${GCP_VM_NAME}" --zone="${GCP_ZONE}" --quiet

gcloud compute instances create "${GCP_VM_NAME}" \
  --zone="${GCP_ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --image-family="ubuntu-2404-lts-amd64" \
  --image-project="ubuntu-os-cloud" \
  --boot-disk-size="30GB" \
  --boot-disk-type="pd-balanced" \
  --network="${GCP_VPC_NAME}" \
  --subnet="${GCP_SUBNET_NAME}" \
  --address="${STATIC_IP}" \
  --service-account="${SA_EMAIL}" \
  --scopes="cloud-platform" \
  --tags="${NETWORK_TAG}" \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --metadata="enable-oslogin=TRUE,block-project-wide-ssh-keys=TRUE,GIT_REPOSITORY_URL=https://github.com/${REPOSITORY}.git" \
  --metadata-from-file="startup-script=${STARTUP_SCRIPT_PATH}" \
  --quiet
