#!/usr/bin/env bash

#===============================================================================
# Deploy Base and Core, then restart RKE2
#===============================================================================
echo
echo "Section: Deploy Base and Core, then restart RKE2"
#===============================================================================
kind delete cluster
kind create cluster --config kind.yaml

sleep 60

REPOSITORY=global-cloudwork/kubernetes
BRANCH=main

# Install infrastructure + CRDs
kubectl kustomize --enable-helm \
  "github.com/$REPOSITORY/kubernetes?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

# Apply workload manifests
kubectl kustomize --enable-helm \
  "github.com/$REPOSITORY/applications/argocd?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

sleep 60

kubectl apply \ 
  -f "https://raw.githubusercontent.com/$REPOSITORY/$BRANCH/kubernetes/core/app-project.yaml" \
  -f "https://raw.githubusercontent.com/$REPOSITORY/$BRANCH/kubernetes/core/application-set.yaml"

sleep 120

./get-credentials.sh
