#!/usr/bin/env bash

# for pod in $(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
#   NAMESPACE=$(echo $pod | cut -d',' -f1)
#   NAME=$(echo $pod | cut -d',' -f2)
#   echo "--- Checking logs for $NAMESPACE/$NAME ---"
#   kubectl logs -n $NAMESPACE $NAME --tail=500 2>/dev/null | grep -i error
#   echo
# done


# kubectl get pods -A -o custom-columns=:.metadata.name --no-headers | xargs -I {} kubectl logs -n argocd {} --tail=500 | grep -i error
# curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/init.sh | bash
#
#sudo journalctl -u google-startup-scripts.service --no-pager
#sudo systemctl status rke2-server.service
#sudo journalctl -u rke2-server -f

BOLD="\e[1m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
RESET="\e[0m"

    cluster:
      name: ${CLUSTER_NAME}
      id: ${CLUSTER_ID}

title()   { printf "\n${BOLD}${UNDERLINE}\e[38;5;231m%s${RESET}\n" "$1"; }
section() { printf "\n${BOLD}${UNDERLINE}\e[38;5;51m%s${RESET}\n" "$1"; }
header()  { printf "\n${ITALIC}\e[38;5;33m%s${RESET}\n\n" "$1"; }
error()   { printf "\n${BOLD}${ITALIC}${UNDERLINE}\e[38;5;106m%s${RESET}\n" "$1"; }
note()    { printf "\n${BOLD}${ITALIC}\e[38;5;82m%s${RESET}\n" "$1"; }

title "Configure RKE2 & Deploy Kustomizations"

section "Setup variables and functions"

header "Importing variables from Google Secret Manager, and GCE Metadata"
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" $EXTERNAL_IP)

PATH=$PATH:/opt/rke2/bin
HOST_IP=$(hostname -I | awk '{print $1}')
export PATH=/var/lib/rancher/rke2/bin:$PATH

declare -a KUSTOMIZE_PATHS=(
  "base/core"
  "applications/argocd"
  "base"
)

section "Organize apt-get, curl files, and inject runtime variables into configurations"

header "apt-get update & install"
sudo apt-get update
sudo apt-get install -y git wireguard

header "Move to /var/lib/rancher/rke2/server/manifests/ and download CRD's"

# Ensure the manifest directory exists
sudo mkdir -p /var/lib/rancher/rke2/server/manifests/

header "download configurations then add runtime variableiables via. envsub"
sudo mkdir -p /etc/rancher/rke2/
sudo curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/base/core/configurations/config.yaml \
| sudo envsubst | sudo tee /etc/rancher/rke2/config.yaml
sudo curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/base/core/configurations/rke2-cilium-config.yaml \
| sudo envsubst | sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml


header "download configurations then add runtime variableiables via. envsub"
sudo curl --remote-name-all --silent --show-error \
    --output-dir /var/lib/rancher/rke2/server/manifests/ \
    https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml \
    https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml \
    https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml \
    https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
    # https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
    # https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
    # https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
    # https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
    # https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
    # https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml \

header "move to /tmp/ then crul and run helm and rke2 installers"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    --remote-name-all \
    --silent \
    --show-error | bash
curl https://get.rke2.io \
    --remote-name-all \
    --silent \
    --show-error | sudo bash

header "Link kubectl command avoiding race conditions"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

header "Enable, then start the rke2-server service"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

sleep 40

header "replace ~./kube/config, after copying the default rke2.yaml"
mkdir -p $HOME/.kube/$CLUSTER_NAME
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"


KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

section "Deploy kustomizations"

kubectl scale deploy cilium-operator --replicas=1 -n kube-system

# Apply CRDs
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml


header "loop through and apply each kustomization path"
for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    header "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$BRANCH" | \
      kubectl apply --server-side --force-conflicts -f -
    
    header "sleeping 10s to allow resources to settle"
    sleep 10
done

kubectl -n argocd rollout restart deployment argocd-server
kubectl -n argocd rollout restart deployment argocd-repo-server
kubectl -n argocd rollout restart deployment argocd-applicationset-controller
kubectl -n argocd rollout restart deployment argocd-notifications-controller
kubectl -n argocd rollout restart deployment argocd-dex-server
kubectl -n argocd rollout restart deployment argocd-redis