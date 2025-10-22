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

#===============================================================================
# Main Script Entry Point
#
#This script has a few sections:
#
#
#===============================================================================
# Allows for the calling of functions
source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/general.sh)
source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/kubernetes.sh)


title "Configure RKE2 & Deploy Kustomizations"

#===============================================================================
# Environment Configuration
#===============================================================================
section "Setup variables and import from google secrets manager"

# Import environment variables from Google Cloud Secret Manager
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

# Retrieve external IP from GCE metadata server
export EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
export INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# Set PATH to include RKE2 binaries
PATH=$PATH:/opt/rke2/bin
export PATH=/var/lib/rancher/rke2/bin:$PATH

# Set cluster-specific variables
HOST_IP=$(hostname -I | awk '{print $1}')

# Set directories where kustomize.yaml files are found
declare -a KUSTOMIZE_PATHS=(
  "base/core"
  "applications/argocd"
  "applications/cert-manager"
  "base"
)

#===============================================================================
# System Dependencies Installation
#===============================================================================
section "Install system dependencies and download configurations"

# Install required system packages
header "apt-get update & install"
sudo apt-get -qq update
sudo apt-get -qq -y install git wireguard

# Install Helm package manager
header "Install Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    --remote-name-all \
    --silent \
    --show-error | bash

# Install RKE2
header "Install RKE2"
curl https://get.rke2.io \
    --remote-name-all \
    --silent \
    --show-error | sudo bash

#===============================================================================
# Configure and start RKE2
#===============================================================================
section "Setup RKE2 configuration files"

# Create necessary directories
sudo mkdir -p /etc/rancher/rke2/
sudo mkdir -p /var/lib/rancher/rke2/server/manifests/

# Download and process RKE2 configuration
# envsubst replaces environment variables in the template
header "Download RKE2 configuration"
sudo curl --silent --show-error --remote-name-all \
  --output-dir /tmp/ \
  https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/base/core/configurations/config.yaml

header "Process RKE2 configuration with envsubst"
sudo --preserve-env envsubst < /tmp/config.yaml \
  | sudo tee /etc/rancher/rke2/config.yaml

# Download and process Cilium configuration
# envsubst replaces environment variables in the template
# header "Download RKE2 Cilium configuration"
# sudo curl --silent --show-error --remote-name-all \
#   --output-dir /tmp/ \
#   https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/base/core/configurations/rke2-cilium-config.yaml

# header "Process RKE2 Cilium configuration with envsubst"
# sudo --preserve-env envsubst < /tmp/rke2-cilium-config.yaml \
#   | sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml

# Enable on boot, then start of RKE2
header "First start of RKE2 to install crd's"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

# Link kubectl command avoiding race conditions
header "Link kubectl command avoiding race conditions"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

# Copy RKE2-generated kubeconfig
# Set proper ownership
mkdir -p $HOME/.kube/$CLUSTER_NAME
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"

# Merge all kubeconfig files in ~/.kube subdirectories
KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

#Deploy initial CRDs for Argo CD, Cert-Manager, and Gateway API
section "Deploy initial CRDs for Argo CD and Gateway API"

ARGOCD_VERSION=v3.1.9
GATEWAY_VERSION=v1.4.0

header "Apply CRDS for Argo CD"
kubectl apply -k github.com/argoproj/argo-cd/manifests/crds?ref=${ARGOCD_VERSION} --server-side
# kubectl apply -k github.com/kubernetes-sigs/gateway-api/config/crd?ref=${GATEWAY_VERSION} --server-side
# kubectl apply -k github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=${GATEWAY_VERSION} --server-side
# kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumgatewayclassconfigs.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

wait_for crds

section "Deploy pre-start manifests"
header "Apply the cilium manifests"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/applications/cilium?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

#Restart RKE2 to pick up new manifests
header "Restart RKE2 to pick up new manifests"
sudo systemctl restart rke2-server.service

# Copy RKE2-generated kubeconfig
# Set proper ownership
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"

# Merge all kubeconfig files in ~/.kube subdirectories
KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

# # # # Wait while pods or nodes are not ready
# # # header "Wait while for pods and nodes to be ready"
# # # ACTIVE_PODS="temp"
# # # ACTIVE_NODES="temp"

# # # while [ -n "$ACTIVE_PODS" ] || [ -n "$ACTIVE_NODES" ]; do
# # #   echo "waiting..."
# # #   ACTIVE_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -vE 'Running|Completed')
# # #   ACTIVE_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -v 'Ready')
# # #   [ -n "$ACTIVE_PODS" ] && echo "Pods not ready: $ACTIVE_PODS"
# # #   [ -n "$ACTIVE_NODES" ] && echo "Nodes not ready: $ACTIVE_NODES"
# # #   sleep 20
# # # done

# section "Deploy pre-start manifests"
# header "Applying Kustomize PATH: base/core"
# kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/core?ref=$BRANCH" | \
#   kubectl apply --server-side --force-conflicts -f -

# section "Deploy argocd manifests"
# header "Applying Kustomize PATH: applications/argocd"
# kubectl kustomize --enable-helm "github.com/$REPOSITORY/applications/argocd?ref=$BRANCH" | \
#   kubectl apply --server-side --force-conflicts -f -

# header "Deploy cert-manager manifests"
# kubectl kustomize --enable-helm "github.com/$REPOSITORY/applications/cert-manager?ref=$BRANCH" | \
#   kubectl apply --server-side --force-conflicts -f -

# wait_for endpoints

# header "Deploy startup manifests"
# kubectl kustomize --enable-helm "github.com/$REPOSITORY/base?ref=$BRANCH" | \
#   kubectl apply --server-side --force-conflicts -f -

# # #Restart RKE2 to ensure all manifests are applied
# # header "Restarting rje2-server to ensure all manifests are applied"
# # sudo systemctl restart rke2-server.service

# # # kubectl -n argocd rollout restart deployment argocd-server
# # # kubectl -n argocd rollout restart deployment argocd-repo-server
# # # kubectl -n argocd rollout restart deployment argocd-applicationset-controller
# # # kubectl -n argocd rollout restart deployment argocd-notifications-controller
# # # kubectl -n argocd rollout restart deployment argocd-dex-server
# # # kubectl -n argocd rollout restart deployment argocd-redis

# # # # RKE2 automatically applies any manifests in this directory at startup
# # # # CRDs must be installed before their corresponding controllers
# # # sudo mkdir -p /var/lib/rancher/rke2/server/manifests/
# # # sudo curl --output-dir /var/lib/rancher/rke2/server/manifests \
# # #     --remote-name-all --silent --show-error \
# # #     https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml \
# # #     https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml \
# # #     https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml \
# # #     https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml \
# # #     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
# # #     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
# # #     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
# # #     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
# # #     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
# # #     https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

# # # # Wait while pods or nodes are not ready
# # # header "Wait while for pods and nodes to be ready"
# # # ACTIVE_PODS="temp"
# # # ACTIVE_NODES="temp"

