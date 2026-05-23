#!/usr/bin/env bash

#===============================================================================
# Deploy Base and Core, then restart RKE2
#===============================================================================
echo
echo "Section: Deploy Base and Core, then restart RKE2"
#===============================================================================
kind delete cluster
kind create cluster --config kind.yaml

REPOSITORY=global-cloudwork/kubernetes
BRANCH=main

# Install infrastructure + CRDs
kubectl kustomize --enable-helm \
  "github.com/$REPOSITORY/kubernetes?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# Apply workload manifests
kubectl kustomize --enable-helm \
  "github.com/$REPOSITORY?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# CILIUM_POD="${kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}'}"