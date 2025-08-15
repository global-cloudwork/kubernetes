#!/bin/bash
./remove-rke2.sh
./install-rke2.sh

# ls -l /etc/rancher/rke2/rke2.yaml
# ls -l "$HOME/.kube/config"

# kubectl wait --for=condition=Ready pods --all --namespace my-namespace --timeout=300s

# echo "Install Tools"
# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes?ref=development" \
#   | kubectl apply -f -

# kubectl wait --for=condition=Ready pods --all --namespace my-namespace --timeout=300s

# echo "Install Core"
# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
#   | kubectl apply -f -
