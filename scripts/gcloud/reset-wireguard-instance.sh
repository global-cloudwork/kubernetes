#!/bin/bash

echo() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}
function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

# ======================== Style Ends Here ========================

INSTANCE_NAME=wireguard
GCP_ZONE=us-central1-a
MACHINE_TYPE=e2-micro
STARTUP_SCRIPT_URL=https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/rke2/install-server.sh

sudo apt-get install -y curl wireguard

wg genkey > private.key
wg pubkey < private.key > public.key

CILIUM_CA=$(kubectl get secret -n kube-system cilium-ca -o yaml | base64 -w0)
PUBLIC_KEY=$(cat public.key)

h1 "Creating Compute Instance $INSTANCE_NAME in Project $GCP_PROJECT"
echo "checking if instance exists..."
if [ -n "$(gcloud compute instances list --filter="name:($INSTANCE_NAME)" --format="value(name)" --project="$GCP_PROJECT" --zones="$GCP_ZONE")" ]; then
    echo "it exists, deleting"
    gcloud compute instances delete "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --quiet
fi

while gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" &> /dev/null; do
    sleep 5
done

gcloud compute instances create "$INSTANCE_NAME" \
    --project="$GCP_PROJECT" \
    --zone="$GCP_ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account="$SERVICE_ACCOUNT" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=wireguard,image=projects/ubuntu-os-cloud/global/images/ubuntu-minimal-2504-plucky-amd64-v20250828,mode=rw,size=15,type=pd-standard \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata=startup-script-url="$STARTUP_SCRIPT_URL",CILIUM-CA="$CILIUM_CA",PUBLIC-KEY="$PUBLIC_KEY",ALLOWED-IPS="$ALLOWED_IPS"

while true; do
    STATUS=$(gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --format='get(status)')
    if [[ "$STATUS" == "RUNNING" ]]; then
        echo "Instance $INSTANCE_NAME is running."
        break
    fi
    echo "Waiting for instance $INSTANCE_NAME to be running..."
    sleep 5
done

gcloud compute ssh ubuntu@$INSTANCE_NAME --project=$GCP_PROJECT --zone=$GCP_ZONE








