#!/bin/bash

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}
function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

# ======================== Style Ends Here ========================

h1 "Resetting Wireguard Instance"

source .env

INSTANCE_NAME=wireguard
GCP_ZONE=us-central1-a
MACHINE_TYPE=e2-micro
STARTUP_SCRIPT_URL=https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/rke2/install-server.sh

h2 "apt installing curl, helm, kubectl"
sudo apt-get install -y curl wireguard

h2 "Generate Wireguard Keys, Curl and decrypt metadata, and set variables"
umask 077
wg genkey > private.key
wg pubkey < private.key > public.key

#Set metadata values for sending to startup script
CILIUM_CA=$(kubectl get secret -n kube-system cilium-ca -o yaml)
PUBLIC_KEY=$(cat public.key)
ALLOWED_IPS=$(hostname -I)

#Encrypt metadata values
CILIUM_CA=$(echo "$CILIUM_CA" | base64 -w0)
PUBLIC_KEY=$(echo "$PUBLIC_KEY" | base64 -w0)
ALLOWED_IPS=$(echo "$ALLOWED_IPS" | base64 -w0)

h1 "Creating Compute Instance $INSTANCE_NAME in Project $GCP_PROJECT"

h2 "checking if instance exists..."
if [ -n "$(gcloud compute instances list --filter="name:($INSTANCE_NAME)" --format="value(name)" --project="$GCP_PROJECT" --zones="$GCP_ZONE")" ]; then
    echo "it exists, deleting"
    gcloud compute instances delete "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --quiet
fi

h2 "waiting for instance to delete..."
while [[ $(gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" &> /dev/null; echo $?) -eq 0 ]]; do
    sleep 5
done

h2 "creating instance..."
gcloud compute instances create "$INSTANCE_NAME" \
    --project="$GCP_PROJECT" \
    --zone="$GCP_ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account="$SERVICE_ACCOUNT" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server,wireguard \
    --image-family=ubuntu-minimal-2504-plucky-amd64 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=10GB \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata=startup-script-url="$STARTUP_SCRIPT_URL",CILIUM-CA="$CILIUM_CA",PUBLIC-KEY="$PUBLIC_KEY",ALLOWED-IPS="$ALLOWED_IPS"
    
h2 "Waiting for instance to be running..."
while true; do
    STATUS=$(gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --format='get(status)')
    if [[ "$STATUS" == "RUNNING" ]]; then
        echo "Instance $INSTANCE_NAME is running."
        break
    fi
    echo "Waiting for instance $INSTANCE_NAME to be running..."
    sleep 5
done

h2 "Streaming startup script output..."
gcloud compute instances tail-serial-port-output "$INSTANCE_NAME" \
    --project="$GCP_PROJECT" \
    --zone="$GCP_ZONE" | grep "Startup script finished"

gcloud compute ssh ubuntu@$INSTANCE_NAME --project=$GCP_PROJECT --zone=$GCP_ZONE

h2 "Endlessly watching serial output for 'STARTUP COMPLETE' message"
gcloud compute instances get-serial-port-output $INSTANCE_NAME --zone=$GCP_ZONE | grep "STARTUP COMPLETE"

gcloud compute instances remove-metadata INSTANCE_NAME \
    --zone=ZONE_NAME \
    --keys=CILIUM-CA,PUBLIC-KEY,ALLOWED-IPS






