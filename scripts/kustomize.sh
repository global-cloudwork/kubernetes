#!/bin/bash
kubectl create secret tls argocd-server-tls -n argocd --key=../../keys/argocd-key.pem --cert=../../keys/argocd.localhost.pem

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml

kubectl create namespace argocd
kubectl create namespace cert-manager

kubectl apply -k https://github.com/kubernetes-sigs/gateway-api/config/crd
kubectl apply -f ../applications/core/cilium/helm-chart-config.crd.yaml
systemctl restart rke2-server

# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
#   | kubectl apply -f -

# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes/applications/core/cert-manager?ref=development" \
#   | kubectl apply -f -

# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes?ref=development" \
#   | kubectl apply -f -

# kubectl create secret tls ca -n argocd --key=../../keys/argocd-key.pem --cert=../../keys/argocd.localhost.pem