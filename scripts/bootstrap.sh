#!/bin/bash
#curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

REVISION=main
REPOSITORY=global-cloudwork/kubernetes
RAW_REPOSITORY=https://raw.githubusercontent.com/$REPOSITORY/$REVISION

CLUSTER_CONFIG_PATH=$RAW_REPOSITORY/configurations/on-site.yaml
HELM_CONFIG_PATH=$RAW_REPOSITORY/configurations/helm-chart-config.crd.yaml

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
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash > /dev/null 2>&1
curl -sfL https://get.rke2.io | sudo sh - > /dev/null 2>&1

echo "Making configuration directories"
mkdir -p /etc/rancher/rke2/
mkdir -p /var/lib/rancher/rke2/server/manifests

echo "Curl cluster config, and helm chart config"
sudo curl -o /etc/rancher/rke2/config.yaml $CLUSTER_CONFIG_PATH
sudo curl -o /var/lib/rancher/rke2/server/manifests/helm-chart-config.crd.yaml $HELM_CONFIG_PATH

echo "Modify configurations to add hostname"
sudo echo -e '\ntls-san:\n  - $(hostname -f)' >> /etc/rancher/rke2/config.yaml

echo "Enable, then start the rke2-server service"
systemctl enable --now rke2-server.service

echo "Add bin for rke2 if not in path"
if ! echo "$PATH" | grep -q "/var/lib/rancher/rke2/bin"; then
  echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin/' >> ~/.bashrc
fi

echo "Configuring path and links that error silently"
export PATH=$PATH:/var/lib/rancher/rke2/bin/
mkdir -p ~/.kube
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl &>/dev/null
sudo ln -s /etc/rancher/rke2/rke2.yaml ~/.kube/config &>/dev/null

echo "Waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=600s

for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    echo "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$REVISION" | \
      kubectl apply --server-side --force-conflicts -f -
done
