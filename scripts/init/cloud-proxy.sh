#sudo journalctl -u google-startup-scripts.service --no-pager
#sudo systemctl status rke2-server.service

#Run as ubuntu after ssh
#curl -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tools/deploy-repo.sh | bash

export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

# For enviroment variable substitution
export PATH=$PATH:/opt/rke2/bin
export HOST_IP=$(hostname -I | awk '{print $1}')
export CLUSTER_NAME=on-site
export CLUSTER_ID=$(($CLUSTER_NAME + 0))

# Values passed to the startup script using encrypted metadata
# AUTHORS_PUBLIC_KEY=$(curl -s -H "Metadata-Flavor: Google" \
#     http://metadata.google.internal/computeMetadata/v1/instance/attributes/public-key)
# AUTHORS_IP=$(curl -s -H "Metadata-Flavor: Google" \
#     http://metadata.google.internal/computeMetadata/v1/instance/attributes/allowed-ips)
# CILIUM_CA=$(curl -s -H "Metadata-Flavor: Google" \
#     http://metadata.google.internal/computeMetadata/v1/instance/attributes/cilium-ca)
# ADDRESS=$(curl -s -H "Metadata-Flavor: Google" \
#     http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip) 

# Cluster details
declare -a PEERS=(
    "${AUTHORS_PUBLIC_KEY},${AUTHORS_IP}"
)
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

h2 "apt update & install"
sudo apt-get update
sudo apt-get install -y git

h2 "Curl and install rke2, helm, and k9s"
# curl -sS https://webinstall.dev/k9s | bash
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sfL https://get.rke2.io | sudo sh -

h2 "Create and write rke2 configuration files"
sudo mkdir -p /etc/rancher/rke2
curl -sL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/configurations/rke2.yaml \
  | envsubst | sudo tee /etc/rancher/rke2/config.yaml > /dev/null

h2 "Create and write cilium configuration files"
sudo mkdir -p /var/lib/rancher/rke2/server/manifests
curl -sL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/configurations/cilium.yaml \
  | envsubst | sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null

# h2 "setting up kubectl"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

h2 "check for if Path does not contain /var/lib/rancher/rke2/bin append"
export PATH=/var/lib/rancher/rke2/bin:$PATH

h2 "Enable, then start the rke2-server service"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

while [ ! -f /etc/rancher/rke2/rke2.yaml ]; do
  h2 "kubeconfig not found..."
  sleep 5
done

# Wait for API to become available
until kubectl get nodes >/dev/null 2>&1; do
  h2 "kubernetes API not ready..."
  sleep 10
done

# # Conditional block to run only if CLUSTER_NAME is "cloud-proxy"
# if [ "$CLUSTER_NAME" == "cloud-proxy" ]; then
#   # Download and apply Cilium CA
#   curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/cilium-ca \
#   | base64 -d | kubectl create -f -

#     # Commented-out secret creation (as in the original code)
#     # kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.example.com.pem
# fi




# kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.example.com.pem
