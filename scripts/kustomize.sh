#!/bin/bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml

kubectl create namespace argocd
kubectl create namespace cert-manager
kubectl create secret tls ca -n argocd --key=../../keys/argocd-key.pem --cert=../../keys/argocd.localhost.pem

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
  | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/cert-manager?ref=development" \
  | kubectl apply -f -
kube
# kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes?ref=development" | kubectl apply -f -

