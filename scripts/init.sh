#!/bin/bash
./remove-rke2.sh
./install-rke2.sh

echo "Install Tools"
kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes?ref=development" \
  | kubectl apply -f -

# kubectl wait --for=condition=Ready pods --all --namespace my-namespace --timeout=300s

echo "Install Core"
kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
  | kubectl apply -f -
