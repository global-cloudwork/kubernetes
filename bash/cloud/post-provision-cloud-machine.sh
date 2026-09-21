#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID environment variable}"
ZONE="${GCP_ZONE:-us-central1-a}"
REGION="${GCP_REGION:-${ZONE%-*}}"
VM_NAME="${GCP_VM_NAME:-gce-kubernetes}"
STATIC_IP_NAME="${GCP_STATIC_IP_NAME:-kubernetes-static-ip}"

echo "==> Waiting for GCE startup provisioning..."
for attempt in $(seq 1 60); do
  if gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --tunnel-through-iap -- \
      "test -f /var/lib/cloud/kubernetes-host-ready" 2>/dev/null; then
    break
  fi
  [[ "${attempt}" -eq 60 ]] && { echo "Startup provisioning timed out" >&2; exit 1; }
  sleep 5
done

STATIC_IP="$(gcloud compute addresses describe "${STATIC_IP_NAME}" \
  --region="${REGION}" --project="${PROJECT_ID}" --format='value(address)')"
echo "Host ready: ${VM_NAME}"
echo "External IP: ${STATIC_IP}"
echo
echo "Log in through IAP and run: sudo /root/bootstrap-kubernetes.sh"
echo "The script installs Kind, kubectl, and Helm, then bootstraps Argo CD."
