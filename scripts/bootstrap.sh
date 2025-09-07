#!/bin/bash
#curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


# sudo apt-get update -y
# sudo apt-get install -y open-iscsi nfs-common util-linux dmsetup cryptsetup
# sudo systemctl enable --now iscsid
# sudo modprobe iscsi_tcp
# sudo modprobe dm_crypt
# echo dm_crypt | sudo tee /etc/modules-load.d/longhorn.conf

# sudo apt update
# sudo apt install nfs-kernel-server
# mkdir -p /nfs && chown nobody:nogroup /nfs
sudo systemctl start nfs-kernel-server.service

CLUSTER_NAME=on-site

DEFAULT_KUBECONFIG=$HOME/.kube/config
RKE2_KUBECONFIG=/etc/rancher/rke2/rke2.yaml

REVISION=main
REPOSITORY=global-cloudwork/kubernetes
RAW_REPOSITORY=https://raw.githubusercontent.com/$REPOSITORY/$REVISION

declare -a KUSTOMIZE_PATHS=(
"components/bootstrap"
"components/applications/argocd"
"components/environments/development"
)

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

h1 "Configure RKE2 & Deploy Kustomizations"

h2 "apt installing curl, helm, kubectl"
sudo apt-get update
sudo apt-get install -y curl

h2 "Curl and install rke2 and helm"
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sfL https://get.rke2.io | sudo sh -

h2 "Making configuration directories"
sudo mkdir -p /etc/rancher/rke2/
sudo mkdir -p /var/lib/rancher/rke2/server/manifests

h2 "Curl cluster config, and helm chart config"
sudo curl -o /etc/rancher/rke2/config.yaml $RAW_REPOSITORY/configurations/clusters/$CLUSTER_NAME/rke2-configuration.yaml
sudo curl -o /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml $RAW_REPOSITORY/configurations/clusters/$CLUSTER_NAME/cilium-configuration.yaml

h2 "Modify configurations to add hostname"
echo -e "tls-san:\n  - $(hostname -I | awk '{print $1}')" | sudo tee -a /etc/rancher/rke2/config.yaml > /dev/null
echo -e "node-name: $CLUSTER_NAME" | sudo tee -a /etc/rancher/rke2/config.yaml > /dev/null

h2 "Enable, then start the rke2-server service"
sudo systemctl enable --now rke2-server.service

while [ ! -f /etc/rancher/rke2/rke2.yaml ]; do
  h2 "kubeconfig not found yet, waiting"
  sleep 5
done

h2 "setting up kubectl"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
PATH=$PATH:/var/lib/rancher/rke2/bin/

h2 "making kubeconfig directories"
mkdir -p "$HOME/.kube/$CLUSTER_NAME"

h2 "linking kubeconfig to subfolder, and merging all kubeconfigs into default location"
ln -sf /etc/rancher/rke2/rke2.yaml "$HOME/.kube/$CLUSTER_NAME/config"
export KUBECONFIG=$(find "$HOME/.kube/" \( -type f -o -type l \) -name config | paste -sd:)

# Flatten all merged kubeconfigs into the default config file
kubectl config view --flatten > "$HOME/.kube/config"

h2 "waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=600s
kubectl wait --for=condition=Ready pods --all --timeout=600s

TOTAL_PATHS=${#KUSTOMIZE_PATHS[@]}
for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    h2 "Applying Kustomize PATH $((CURRENT_PATH + 1)) of $TOTAL_PATHS: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$REVISION" | \
      kubectl apply --server-side --force-conflicts -f -
    kubectl wait --for=condition=complete jobs --all -A --timeout=600s || true
    kubectl wait --for=condition=running pods --all -A --timeout=600s || true
done

# kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.example.com.pem