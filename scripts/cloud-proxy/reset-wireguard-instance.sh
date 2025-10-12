#!/bin/bash
set -euo pipefail

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}
function h1() {
    command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

# ======================== Style Ends Here ========================

export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

h1 "Creating Compute Instance $INSTANCE_NAME in Project $GCP_PROJECT"

# h2 "apt installing wireguard"
sudo apt-get install -y wireguard

h2 "Generate Wireguard Keys, Curl and decrypt metadata, and set variables"
wg genkey > $PRIVATE_KEY
wg pubkey < $PRIVATE_KEY > $PUBLIC_KEY

h2 "Getting environment variables from rke2 cluster"
CILIUM_CA=$(kubectl get secret -n kube-system cilium-ca -o yaml)
TOKEN=$(sudo cat /var/lib/rancher/rke2/server/node-token)

h2 "updating secrets in secret manager"
gcloud secrets versions add public-key \
    --data-file=- < "$PUBLIC_KEY"
gcloud secrets versions add cilium-certificate \
    --data-file=- <<< "$CILIUM_CA"
gcloud secrets versions add on-site-token \
    --data-file=- <<< "$TOKEN"

h2 "checking if instance exists..."
if [ -n "$(gcloud compute instances list --filter="name:($INSTANCE_NAME)" --format="value(name)" --project="$GCP_PROJECT" --zones="$GCP_ZONE")" ]; then
    echo "it exists, deleting"
    gcloud compute instances delete "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --quiet
fi

h2 "Waiting for instance to delete"
while [[ $(gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" &> /dev/null; echo $?) -eq 0 ]]; do
    sleep 5
done

h2 "Creating instance $INSTANCE_NAME"
gcloud compute instances create "$INSTANCE_NAME" \
    --project="$GCP_PROJECT" \
    --zone="$GCP_ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --scopes=cloud-platform \
    --service-account="$SERVICE_ACCOUNT" \
    --tags=http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=wireguard,image="$IMAGE",mode=rw,size=15,type=pd-standard \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata=startup-script-url="$STARTUP_SCRIPT_URL"
    
h2 "Waiting for instance to be running"
while true; do
    STATUS=$(gcloud compute instances describe "$INSTANCE_NAME" \
        --project="$GCP_PROJECT" \
        --zone="$GCP_ZONE" \
        --format='get(status)' 2>/dev/null)

    if [[ "$STATUS" == "RUNNING" ]]; then
        break
    fi

    h2 "Waiting..."
    sleep 30
done
h2 "Wait finished, instance is running..."

gcloud compute ssh ubuntu@$INSTANCE_NAME \
    --project=$GCP_PROJECT 
    --zone=$GCP_ZONE 
    --ssh-flag="-o UserKnownHostsFile=/dev/null"
