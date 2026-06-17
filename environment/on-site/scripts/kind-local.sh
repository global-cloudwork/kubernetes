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

# Wait 60 seconds for cluster stabilization before obtaining credentials
sleep 60
./get-credentials.sh 
