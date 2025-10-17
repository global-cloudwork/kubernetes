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

# Print formatted section headers
BOLD="\e[1m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
RESET="\e[0m"

title()   { printf "\n${BOLD}${UNDERLINE}\e[38;5;231m%s${RESET}\n" "$1"; }
section() { printf "\n${BOLD}${UNDERLINE}\e[38;5;51m%s${RESET}\n" "$1"; }
header()  { printf "\n${ITALIC}\e[38;5;33m%s${RESET}\n\n" "$1"; }
error()   { printf "\n${BOLD}${ITALIC}${UNDERLINE}\e[38;5;106m%s${RESET}\n" "$1"; }
note()    { printf "\n${BOLD}${ITALIC}\e[38;5;82m%s${RESET}\n" "$1"; }

#===============================================================================
# Main Script Entry Point
#
#This script has a few sections:
#
#
#===============================================================================
title "Configure RKE2 & Deploy Kustomizations"

#===============================================================================
# Environment Configuration
#===============================================================================
section "Setup variables and import from google secrets manager"

# Import environment variables from Google Cloud Secret Manager
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

# Retrieve external IP from GCE metadata server
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" $EXTERNAL_IP)

# Set PATH to include RKE2 binaries
PATH=$PATH:/opt/rke2/bin
export PATH=/var/lib/rancher/rke2/bin:$PATH

# Set cluster-specific variables
HOST_IP=$(hostname -I | awk '{print $1}')

# Set directories where kustomize.yaml files are found
declare -a KUSTOMIZE_PATHS=(
  "base/core"
  "applications/argocd"
  "base"
)

#===============================================================================
# System Dependencies Installation
#===============================================================================
section "Install system dependencies and download configurations"

# Install required system packages
header "apt-get update & install"
sudo apt-get -qq update
sudo apt-get -qq -y install  git wireguard

# Install Helm package manager
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    --remote-name-all \
    --silent \
    --show-error | bash

# Install RKE2
curl https://get.rke2.io \
    --remote-name-all \
    --silent \
    --show-error | sudo bash

# First start of RKE2 to install crd's
systemctl enable rke2-server.service
systemctl start rke2-server.service

header "Link kubectl command avoiding race conditions"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

# Apply Argo CD CRDs
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml

# Apply Cert-Manager CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml

# Apply Gateway API CRDs (Standard)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml

# Apply Gateway API CRDs (Experimental)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

#===============================================================================
# Configure and start RKE2
#===============================================================================
section "Setup RKE2 configuration files"

# Download and process RKE2 configuration
# envsubst replaces environment variables in the template
sudo curl --silent --show-error --remote-name-all \
  https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/base/core/configurations/config.yaml \
  | sudo envsubst | sudo tee /etc/rancher/rke2/config.yaml

# Download and process Cilium configuration
# envsubst replaces environment variables in the template
sudo curl --silent --show-error --remote-name-all \
  https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/base/core/configurations/rke2-cilium-config.yaml \
  | sudo envsubst | sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml

systemctl restart rke2-server.service

#===============================================================================
# Configure RKE2 further, and install cilium
#===============================================================================
section "Configure RKE2 further, and install cilium"

# Copy RKE2-generated kubeconfig
# Set proper ownership
mkdir -p $HOME/.kube/$CLUSTER_NAME
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"

# Merge all kubeconfig files in ~/.kube subdirectories
KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

# Wait while pods or nodes are not ready
header "Wait while for pods and nodes to be ready"
ACTIVE_PODS="temp"
ACTIVE_NODES="temp"

# while [ -n "$ACTIVE_PODS" ] || [ -n "$ACTIVE_NODES" ]; do
#   echo "waiting..."
#   ACTIVE_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -vE 'Running|Completed')
#   ACTIVE_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -v 'Ready')
#   [ -n "$ACTIVE_PODS" ] && echo "Pods not ready: $ACTIVE_PODS"
#   [ -n "$ACTIVE_NODES" ] && echo "Nodes not ready: $ACTIVE_NODES"
#   sleep 20
# done

section "Deploy kustomizations"

header "loop through and apply each kustomization path"
for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    header "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$BRANCH" | \
      kubectl apply --server-side --force-conflicts -f -
    
    header "sleeping 10s to allow resources to settle"
    sleep 20
done

# kubectl -n argocd rollout restart deployment argocd-server
# kubectl -n argocd rollout restart deployment argocd-repo-server
# kubectl -n argocd rollout restart deployment argocd-applicationset-controller
# kubectl -n argocd rollout restart deployment argocd-notifications-controller
# kubectl -n argocd rollout restart deployment argocd-dex-server
# kubectl -n argocd rollout restart deployment argocd-redis

# # RKE2 automatically applies any manifests in this directory at startup
# # CRDs must be installed before their corresponding controllers
# sudo mkdir -p /var/lib/rancher/rke2/server/manifests/
# sudo curl --output-dir /var/lib/rancher/rke2/server/manifests \
#     --remote-name-all --silent --show-error \
#     https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml \
#     https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml \
#     https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml \
#     https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml \
#     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
#     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
#     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
#     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
#     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
#     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

# # Wait while pods or nodes are not ready
# header "Wait while for pods and nodes to be ready"
# ACTIVE_PODS="temp"
# ACTIVE_NODES="temp"

# # Install Cilium with specific configuration
# helm repo add cilium https://helm.cilium.io/
# helm repo update
# helm install cilium cilium/cilium \
#   --namespace kube-system \
#   --set encryption.enabled=true \
#   --set encryption.type=wireguard \
#   --set kubeProxyReplacement=true \
#   --set k8sServiceHost=127.0.0.1 \
#   --set k8sServicePort=6443 \
#   --set operator.replicas=1 \
#   --set hubble.enabled=true \
#   --set hubble.relay.enabled=true \
#   --set hubble.ui.enabled=true \
#   --set gatewayAPI.enabled=true 