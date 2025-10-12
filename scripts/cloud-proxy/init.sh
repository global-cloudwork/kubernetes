#!/usr/bin/env bash
#sudo journalctl -u google-startup-scripts.service --no-pager
#sudo systemctl status rke2-server.service

title()   { printf "\033[1;4;38;5;231m# %s\033[0m\n" "$1"; }   # Bright white
section() { printf "\033[1;38;5;51m# %s\033[0m\n" "$1"; }       # Cyan
header()  { printf "\033[1;3;38;5;33m## %s\033[0m\n" "$1"; }    # Blue
error()   { printf "\033[1;4;38;5;196mError:\033[0m \033[1m%s\033[0m\n" "$1"; }  # Bright red
note()    { printf "\033[1;3;38;5;82mNote:\033[0m \033[1m%s\033[0m\n" "$1"; }   # Bright green

title "Configure RKE2 & Deploy Kustomizations"

section "Setup variables and functions"

header "Importing variables from Google Secret Manager, and GCE Metadata"
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" $EXTERNAL_IP)

PATH=$PATH:/opt/rke2/bin
HOST_IP=$(hostname -I | awk '{print $1}')
CLUSTER_ID=$(($CLUSTER_NAME + 0))
export PATH=/var/lib/rancher/rke2/bin:$PATH

declare -a KUSTOMIZE_PATHS=(
  "components/bootstrap"
  "components/applications/argocd"
  "components/environments/development"
)

section "updating, installing, and dependencies"

header "apt-get update & install dependencies"
sudo apt-get update 
sudo apt-get install -y git wireguard

header "move to /tmp/ and download and install helm and rke2"
cd /tmp/
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    --remote-name-all --silent --show-error | bash
curl https://get.rke2.io \
    --remote-name-all --silent --show-error | bash    

header "move /var/lib/rancher/rke2/server/manifests/ and download CRD's"
note "CRD's must be present prior to starting RKE2 to avoid errors"
cd /var/lib/rancher/rke2/server/manifests/
sudo curl --remote-name-all --silent --show-error \
    https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
    https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
    https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
    https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
    https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
    https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml \
    https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml \
    https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml \
    https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml \
    https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml

header "move to /etc/rancher/rke2/ then download, then add runtime variable sto configuration files"
cd /etc/rancher/rke2/
sudo curl --remote-name-all --silent --show-error \
    https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/configurations/config.yaml \
    https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/configurations/rke2-cilium-config.yaml

header "Link kubectl command avoiding race conditions"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

header "Enable, then start the rke2-server service"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

sleep 40

header "replace ~./kube/config, after copying the default rke2.yaml"
mkdir -p $HOME/.kube/$CLUSTER_NAME
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

section "Deploy kustomizations"

header "loop through and apply each kustomization path"
for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    header "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$BRANCH" | \
      kubectl apply --server-side --force-conflicts -f -
    
    header "sleeping 10s to allow resources to settle"
    sleep 10
done