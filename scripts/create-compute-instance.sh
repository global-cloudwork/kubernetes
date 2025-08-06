#!/bin/bash

# Run this script:
# curl -sSL https://raw.githubusercontent.com/mcconnellj/k3s-server/main/scripts/create-e2-server.sh?nocache=$(date +%s) | bash

# Load environment variables from the .env file if needed
source .env

if gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" &> /dev/null; then
    echo "Instance $INSTANCE_NAME exists. Deleting..."
    gcloud compute instances delete "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" --quiet
    echo "Waiting for instance $INSTANCE_NAME to be deleted..."
    while gcloud compute instances describe "$INSTANCE_NAME" --project="$GCP_PROJECT" --zone="$GCP_ZONE" &> /dev/null; do
        sleep 5
    done
    echo "Instance $INSTANCE_NAME deleted."
fi

gcloud compute instances create "$INSTANCE_NAME" \
  --project="$GCP_PROJECT" \
  --zone="$GCP_ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --network-interface=network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default \
  --provisioning-model=SPOT \
  --instance-termination-action=STOP \
  --service-account="$SERVICE_ACCOUNT" \
  --tags=http-server,https-server \
  --create-disk=auto-delete=yes,boot=yes,mode=rw,size=10,type=pd-balanced,image=ubuntu-minimal-2404-noble-amd64-v20250725,image-project=ubuntu-os-cloud \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=goog-ec-src=vm_add-gcloud \
  --reservation-affinity=any \
  --metadata=startup-script-url="https://raw.githubusercontent.com/mcconnellj/kubernetes/production/scripts/init-server.sh?nocache=$(date +%s)"


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

# kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable
# https://github.com/argoproj/argo-cd/blob/master/manifests/install.yaml