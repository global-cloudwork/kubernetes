#!/bin/bash
#curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


CLUSTER_NAME=cloud-proxy

DEFAULT_KUBECONFIG=$HOME/.kube/config
RKE2_KUBECONFIG=/etc/rancher/rke2/rke2.yaml
CLUSTER_STORAGE_PATH="$HOME/Documents/kube"

REVISION=main
REPOSITORY=global-cloudwork/kubernetes
RAW_REPOSITORY=https://raw.githubusercontent.com/$REPOSITORY/$REVISION

RKE2_CONFIGURATION_PATH=$RAW_REPOSITORY/configurations/clusters/$CLUSTER_NAME/rke2-configuration.yaml
CILIUM_CONFIGURATION_PATH=$RAW_REPOSITORY/configurations/clusters/$CLUSTER_NAME/cilium-configuration.yaml

declare -a KUSTOMIZE_PATHS=(
"components/bootstrap"
"components/applications/argocd"
"components/environments/development"
)

echo() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

h1 "Configure RKE2 & Deploy Kustomizations"

echo "Installing curl, helm, kubectl"
sudo apt-get update
sudo apt-get install -y curl

echo "Curl and install rke2 and helm"
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sfL https://get.rke2.io | sudo sh -

echo "Making configuration directories"
mkdir -p /etc/rancher/rke2/
mkdir -p /var/lib/rancher/rke2/server/manifests

echo "Curl cluster config, and helm chart config"
sudo curl -o /etc/rancher/rke2/config.yaml $RKE2_CONFIGURATION_PATH
sudo curl -o /var/lib/rancher/rke2/server/manifests/cilium-configuration.yaml $CILIUM_CONFIGURATION_PATH

echo "Modify configurations to add hostname"
sudo echo -e '\ntls-san:\n  - $(hostname -f)' >> /etc/rancher/rke2/config.yaml
sudo echo -e '\nnode-name: '$CLUSTER_NAME >> /etc/rancher/rke2/config.yaml

echo "Enable, then start the rke2-server service"
systemctl enable --now rke2-server.service

echo "Configuring path and links that error silently"

sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
export PATH=$PATH:/var/lib/rancher/rke2/bin/

mkdir -p $HOME/.kube

ln -sf /etc/rancher/rke2/rke2.yaml "$HOME/.kube/config"

echo "Waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=600s

for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    echo "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$REVISION" | \
      kubectl apply --server-side --force-conflicts -f -
done

#Pair in reset-cloud-instance.sh
#Takes in ca as metadata, creates secret
curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/cilium-ca \
| base64 -d | kubectl create -f -

# kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.example.com.pem