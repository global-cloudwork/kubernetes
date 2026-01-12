#!/usr/bin/env bash
# CILIUM_POD="${kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}'}"
# kubectl logs -n kube-system cilium-4qf4f -c cilium-agent | grep -E 'BPF|failed|error|warn|host routing|Legacy'


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


export ../../../
PATH=$PATH:/opt/rke2/bin

git config --global user.email "josh.v.mcconnell@gmail.com"
git config --global user.name "josh m"

# Install Helm and RKE2
# curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
#    --remote-name-all --silent --show-error | bash

# Deploy core
echo
echo "Applying Kustomize PATH: base/core/kustomization.yaml"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/core?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# Deploy root
echo
echo "Applying Kustomize PATH: /kustomization.yaml"
kubectl kustomize --enable-helm "github.com/$REPOSITORY?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# Swap in cilium cni none
# sed -i 's/^cni: none$/cni: cilium/' /etc/rancher/rke2/config.yaml

echo
echo "Switching CNI to Cilium in /etc/rancher/rke2/config.yaml"
sudo sed -i -e '/^cni: none/d' -e '$a cni: cilium' /etc/rancher/rke2/config.yaml

# Restart RKE2 to pick up new manifests
echo
echo "Restart RKE2 to pick up new manifests"
sudo systemctl restart rke2-server.service

echo
echo "Sleeping 1 minute to allow RKE2 to restart"
sleep 1m

#===============================================================================
# Deploy Edge and Tenant
#===============================================================================
echo
echo "Section: Deploy Edge and Tenant"
#===============================================================================

# Deploy edge
echo
echo "Applying Kustomize PATH: base/edge/kustomization.yaml"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/edge?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# # # Wait for deployments and pods to be ready
# # kubectl -n cert-manager wait --for=condition=available "deployment/cert-manager-webhook" --timeout="180s"
# # kubectl -n cert-manager wait --for=condition=ready pod -l "app.kubernetes.io/name=webhook" --timeout="180s"

# Deploy tenant
echo
echo "Applying Kustomize PATH: base/tenant/kustomization.yaml"
kubectl kustomize --enable-helm "github.com/$REPOSITORY/base/tenant?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# Create dns challenge key
gcloud secrets versions access latest \
  --secret="dns-solver-json-key" \
  --project="global-cloudworks" \
  > key.json

kubectl create secret generic dns-key \
  --from-file=key.json \
  --namespace=gateway

kubectl create secret generic dns-key \
  --from-file=key.json \
  --namespace=cert-manager

rm key.json