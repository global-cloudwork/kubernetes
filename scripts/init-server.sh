#!/bin/bash

# ==============================================================================
# LOGGING AND INITIAL CHECKS
# ==============================================================================
echo "--- Startup Script Started: $(date) ---"
echo "Running as user: $USER"
echo "Current directory: $(pwd)"
echo "--------------------------------------------------------"

# Remove redundant `sudo` commands, as cloud-init scripts run as root by default.
# The `||` pattern ensures the script stops if a command fails, preventing cascading errors.

# ==============================================================================
# SYSTEM PACKAGE MANAGEMENT
# ==============================================================================
echo "Updating system packages..."
apt update
apt upgrade -y

# ==============================================================================
# DOWNLOAD AND EXTRACT KUBERNETES MANIFESTS
# ==============================================================================
echo "Downloading Kubernetes manifests from GitHub..."
curl -L -o kubernetes.tar.gz "https://github.com/mcconnellj/kubernetes/archive/refs/heads/production.tar.gz?nocache=$(date +%s)"
echo "Extracting tarball..."
tar -xzvf kubernetes.tar.gz
rm kubernetes.tar.gz

# Ensure `mkdir` command is outside of the `mv` command to prevent race conditions.
echo "Creating k3s manifests directory..."
mkdir -p /var/lib/rancher/k3s/server/manifests

echo "Moving initialization files to k3s manifests directory..."
mv -f ./kubernetes-production/kubernetes/initialization/* /var/lib/rancher/k3s/server/manifests/
# mv -f ./kubernetes-production/scripts/k3s.sh /etc/profile.d/k3s.sh

echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" > /etc/profile.d/k3s.sh
chmod 600 /etc/rancher/k3s/k3s.yaml

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -

wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb
apt install ./k9s_linux_amd64.deb
rm k9s_linux_amd64.deb

echo "--- Startup Script Finished Successfully: $(date) ---"

# kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
# kubectl port-forward svc/argocd-server -n argocd 8080:443
