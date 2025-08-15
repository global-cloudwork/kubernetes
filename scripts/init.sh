#!/bin/bash
./remove-rke2.sh
./install-rke2.sh

sudo chmod a+r /etc/rancher/rke2/rke2.yaml

# ls -l /etc/rancher/rke2/rke2.yaml
# ls -l "$HOME/.kube/"

echo Installing CRD's
kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/tools?ref=development" \
  | kubectl apply -f -

# echo Waiting For CRD's
# kubectl wait --for=condition=Established crd --all --timeout=300s

# echo Installing Cilium
echo "Install Cilium"
kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/cilium?ref=development" \
  | kubectl apply -f -

# kubectl wait --for=condition=Ready pods --all --namespace my-namespace --timeout=300s

# echo "Install Core"
# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
#   | kubectl apply -f -
