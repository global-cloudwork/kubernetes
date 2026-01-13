#!/usr/bin/env bash
# CILIUM_POD="${kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}'}"
# kubectl logs -n kube-system cilium-4qf4f -c cilium-agent | grep -E 'BPF|failed|error|warn|host routing|Legacy'

source ./.on-site.dev.env

#kubectl -n kube-system exec $(kubectl -n kube-system get pod -o name | grep cilium-operator | head -n 1) -- cilium status


# kubectl -n kube-system exec -it cilium-l7hrc -- bash
# cilium status

# kubectl logs -n kube-system $(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -c cilium-agent | grep -E 'BPF|failed|error|warn|host routing|Legacy'
# kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl exec -n kube-system {} -- cilium-dbg <command>

# kubectl run <pod-name> \
#   --rm -it \
#   --restart=Never \
#   --image=<image-name> \
#   -- sh -c "<command-to-run>"

# for pod in $(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
#   NAMESPACE=$(echo $pod | cut -d',' -f1)
#   NAME=$(echo $pod | cut -d',' -f2)
#   echo "--- Checking logs for $NAMESPACE/$NAME ---"
#   kubectl logs -n $NAMESPACE $NAME --tail=500 2>/dev/null | grep -i error
#   echo
# done


# kubectl get pods -A -o custom-columns=:.metadata.name --no-headers | xargs -I {} kubectl logs -n argocd {} --tail=500 | grep -i error
# curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/gateway/init-gateway.sh | bash
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

# # Import environment variables from Secret Manager, instance metadata, and bash
# export $(gcloud secrets versions access latest --secret=development-env-file | xargs)
# export EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
# export INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
# ## Disabled: external test functions are no longer fetched
# # source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/functions/test-functions.sh)
# # Set PATH to include rke2 binaries
# export PATH=/var/lib/rancher/rke2/bin:$PATH
# PATH=$PATH:/opt/rke2/bin

# git config --global user.email "josh.v.mcconnell@gmail.com"
# git config --global user.name "josh m"

# #===============================================================================
# # Prepare the host system
# #===============================================================================
# echo
# echo "Section: Prepare the host system"
# #===============================================================================

# mkdir -p $HOME/.kube/$CLUSTER_NAME

# # Install Helm and RKE2
# curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
#     --remote-name-all --silent --show-error | bash

# # For AMD64 / x86_64
# [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
# chmod +x ./kind
# sudo mv ./kind /usr/local/bin/kind

# kind create cluster --config=kind-config.yaml

# echo "Sleeping 1 minute"
# sleep 1m

# # Copy RKE2-generated kubeconfig, set proper ownership, and merge all kubeconfig files
# sudo cp -f /etc/rancher/rke2/rke2.yaml $HOME/.kube/$CLUSTER_NAME/config
# sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"
# KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
# sudo kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

#===============================================================================
# Deploy Base and Core, then restart RKE2
#===============================================================================
echo
echo "Section: Deploy Base and Core, then restart RKE2"
#===============================================================================

kind create cluster --config kind.yaml

kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.9/manifests/install.yaml

kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/core?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -
kubectl kustomize --enable-helm "github.com/$REPOSITORY?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -
# kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/edge?ref=$BRANCH" | \
#   kubectl apply --server-side --force-conflicts -f -
# kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/tenant?ref=$BRANCH" | \
#   kubectl apply --server-side --force-conflicts -f -

# # Create dns challenge key
# gcloud secrets versions access latest \
#   --secret="dns-solver-json-key" \
#   --project="global-cloudworks" \
#   > key.json

# kubectl create secret generic dns-key \
#   --from-file=key.json \
#   --namespace=gateway

# kubectl create secret generic dns-key \
#   --from-file=key.json \
#   --namespace=cert-manager

rm key.json