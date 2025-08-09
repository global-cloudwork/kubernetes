#!/bin/bash

# Fix k3s kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
chmod 644 /etc/rancher/k3s/k3s.yaml


# Bootstrap Manifests
kubectl create namespace argocd
kubectl apply \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml \
  -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml \

kubectl apply -k https://github.com/kubernetes-sigs/external-dns//kustomize


# Fetch Password 
# kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

