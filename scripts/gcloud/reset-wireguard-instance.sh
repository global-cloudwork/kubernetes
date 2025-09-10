#!/bin/bash

echo() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

CILIUM_CA=$(kubectl get secret -n kube-system cilium-ca -o yaml | base64 -w0)

source .env

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
    --zone="$GCP_ZONE" \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --tags=wireguard \
    --metadata=startup-script-url=https://raw.githubusercontent.com/your-username/your-repo/main/startup.sh

gcloud compute instances create "$INSTANCE_NAME" \
  --project="$GCP_PROJECT" \
  --zone="$GCP_ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --network-interface=network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default \
  --provisioning-model=SPOT \
  --instance-termination-action=STOP \
  --service-account="$SERVICE_ACCOUNT" \
  --tags=http-server,https-server \
  --create-disk=auto-delete=yes,boot=yes,mode=rw,size=10,type=pd-balanced,image="@UBUNTU_IMAGE",image-project=ubuntu-os-cloud \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=goog-ec-src=vm_add-gcloud \
  --reservation-affinity=any \
  --metadata=startup-script-url="https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/bootstrap.sh" #,cilium-ca-secret="$CILIUM_CA"

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


