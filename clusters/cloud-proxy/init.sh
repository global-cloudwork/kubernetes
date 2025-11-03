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
#sudo ss -tulnp

#===============================================================================
# Main Script Entry Point
#
#This script has a few sections:
#
#
#===============================================================================

# Import environment variables from Secret Manager, instance metadata, and bash
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)
export EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
export INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/general.sh)
source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/kubernetes.sh)
source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/test-functions.sh)
# Set PATH to include rke2 binaries
export PATH=/var/lib/rancher/rke2/bin:$PATH
PATH=$PATH:/opt/rke2/bin




#===============================================================================
# Prepare the host system
#===============================================================================
section "Prepare the host system"
#===============================================================================

# Install required system packages and create necessary directories
header "apt-get update & install"
sudo apt-get -qq update
sudo apt-get -qq -y install git wireguard
mkdir -p $HOME/.kube/$CLUSTER_NAME
sudo mkdir -p /etc/rancher/rke2/
sudo mkdir -p /var/lib/rancher/rke2/server/manifests/
sudo touch /etc/rancher/rke2/cloud.conf

# Download RKE2 configuration files, then substitute environment variables
sudo curl --silent --show-error --remote-name-all --output-dir /tmp/ \
  https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/configurations/config.yaml
sudo --preserve-env envsubst < /tmp/config.yaml | sudo tee /etc/rancher/rke2/config.yaml

# Install Helm and RKE2
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    --remote-name-all --silent --show-error | bash
curl https://get.rke2.io \
  --remote-name-all --silent --show-error | sudo bash




#===============================================================================
# Configure and start the RKE2 service
#===============================================================================
section "Configure and start the RKE2 service"
#===============================================================================

# Enable on boot, then start of RKE2
header "First start of RKE2 to install crd's"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

# Link kubectl command avoiding race conditions
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

# Copy RKE2-generated kubeconfig, set proper ownership, and merge all kubeconfig files
sudo cp -f /etc/rancher/rke2/rke2.yaml $HOME/.kube/$CLUSTER_NAME/config
sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"
KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null




#===============================================================================
# Deploy Base and Core, then restart RKE2
#===============================================================================
section "Deploy Base and Core, then restart RKE2"
#===============================================================================

# Deploy base
header "Applying Kustomize PATH: base"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

wait_for crds

# Deploy core
header "Applying Kustomize PATH: base/core"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/core?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# Restart RKE2 to pick up new manifests
header "Restart RKE2 to pick up new manifests"
sudo systemctl restart rke2-server.service




#===============================================================================
# Deploy Edge and Tenant
#===============================================================================
section "Deploy Edge and Tenant"
#===============================================================================

header "Waiting for cert-manager to be ready"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n cert-manager --timeout=300s

# Deploy edge
header "Applying Kustomize PATH: base/edge"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/edge?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# # Wait for deployments and pods to be ready
# kubectl -n cert-manager wait --for=condition=available "deployment/cert-manager-webhook" --timeout="180s"
# kubectl -n cert-manager wait --for=condition=ready pod -l "app.kubernetes.io/name=webhook" --timeout="180s"

# Deploy tenant
header "Applying Kustomize PATH: base/tenant"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/tenant?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# # Copy RKE2-generated kubeconfig, set proper ownership, and merge all kubeconfig files
# sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
# sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"
# KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
# sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

# # Create dns challenge key
# gcloud secrets versions access latest \
#   --secret="dns-solver-json-key" \
#   --project="global-cloudworks" \
#   > dns-key.json

# kubectl create secret generic dns-key --from-file=dns-key.json
# rm dns-key.json




# header "Installing iptables-persistent for rule persistence"
# sudo DEBIAN_FRONTEND=noninteractive apt-get -qq install -y iptables-persistent netfilter-persistent

# header "Enabling IP forwarding"
# cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf > /dev/null
# net.ipv4.ip_forward = 1
# net.ipv6.conf.all.forwarding = 1
# net.bridge.bridge-nf-call-iptables = 1
# net.bridge.bridge-nf-call-ip6tables = 1
# EOF
# sudo sysctl --system > /dev/null 2>&1

# # HTTP: Redirect external 80 → 8080
# # HTTPS: Redirect external 443 → 8443
# sudo iptables -t nat -C PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080 2>/dev/null || \
# sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
# sudo iptables -t nat -C PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443 2>/dev/null || \
# sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

# # Allow traffic on high ports
# sudo iptables -t filter -C INPUT -p tcp --dport 8080 -j ACCEPT 2>/dev/null || \
# sudo iptables -t filter -A INPUT -p tcp --dport 8080 -j ACCEPT
# sudo iptables -t filter -C INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null || \
# sudo iptables -t filter -A INPUT -p tcp --dport 8443 -j ACCEPT

# # Save rules persistently
# header "Saving iptables rules persistently"
# sudo netfilter-persistent save
# note "✓ iptables rules saved and will persist across reboots"

# # Display active rules
# header "Active NAT rules:"
# sudo iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E "dpt:80|dpt:443" || echo "No matching rules found"
