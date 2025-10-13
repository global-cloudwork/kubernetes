#!/bin/bash

BOLD="\e[1m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
RESET="\e[0m"

title()   { printf "\n${BOLD}${UNDERLINE}\e[38;5;231m%s${RESET}\n" "$1"; }
section() { printf "\n${BOLD}${UNDERLINE}\e[38;5;51m%s${RESET}\n" "$1"; }
header()  { printf "\n${ITALIC}\e[38;5;33m%s${RESET}\n\n" "$1"; }
error()   { printf "\n${BOLD}${ITALIC}${UNDERLINE}\e[38;5;106m%s${RESET}\n" "$1"; }
note()    { printf "\n${BOLD}${ITALIC}\e[38;5;82m%s${RESET}\n" "$1"; }

# ======================== Style Ends Here ========================

export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

title "Creating Compute Instance $INSTANCE_NAME in Project $GCP_PROJECT"

header "apt installing wireguard"
sudo apt-get install -y wireguard

header "Generate Wireguard Keys, Curl and decrypt metadata, and set variables"
wg genkey > $PRIVATE_KEY
wg pubkey < $PRIVATE_KEY > $PUBLIC_KEY

header "Getting environment variables from rke2 cluster"
CILIUM_CA=$(kubectl get secret -n kube-system cilium-ca -o yaml)
TOKEN=$(sudo cat /var/lib/rancher/rke2/server/node-token)

header "updating secrets in secret manager"
gcloud secrets versions add public-key \
    --data-file=- < "$PUBLIC_KEY"
gcloud secrets versions add cilium-certificate \
    --data-file=- <<< "$CILIUM_CA"
gcloud secrets versions add on-site-token \
    --data-file=- <<< "$TOKEN"

header "checking if instance exists..."
if [ -n "$(gcloud compute instances list --filter="name:($INSTANCE_NAME)" --format="value(name)" --project="$GCP_PROJECT" --zones="$GCP_ZONE")" ]; then
    echo "it exists, deleting"
    gcloud compute instances delete "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --quiet
fi

header "Waiting for instance to delete"
while [[ $(gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" &> /dev/null; echo $?) -eq 0 ]]; do
    sleep 5
done

header "Creating instance $INSTANCE_NAME"
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
    --reservation-affinity=any 
    # --metadata=startup-script-url="$STARTUP_SCRIPT_URL"
    
header "Waiting for instance to be running"
while true; do
    STATUS=$(gcloud compute instances describe "$INSTANCE_NAME" \
        --project="$GCP_PROJECT" \
        --zone="$GCP_ZONE" \
        --format='get(status)' 2>/dev/null)

    if [[ "$STATUS" == "RUNNING" ]]; then
        break
    fi

    header "Waiting..."
    sleep 30
done
header "Wait finished, instance is running..."

gcloud compute ssh ubuntu@$INSTANCE_NAME \
    --project=$GCP_PROJECT \
    --zone=$GCP_ZONE \
    --ssh-flag="-o UserKnownHostsFile=/dev/null"
