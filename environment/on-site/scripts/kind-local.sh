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

# Generate Authentik secret key
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 36)

kubectl create secret generic authentik-secret-key \
  --namespace authentik \
  --from-literal=secret_key="$AUTHENTIK_SECRET_KEY" \
  --dry-run=client -o yaml | \
  kubectl apply -f -

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
  -f "https://raw.githubusercontent.com/$REPOSITORY/$BRANCH/kubernetes/core/application-set.yaml" \
  -f "https://raw.githubusercontent.com/$REPOSITORY/$BRANCH/kubernetes/core/gateway.yaml"

sleep 120

./get-credentials.sh