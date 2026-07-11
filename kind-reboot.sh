#!/usr/bin/env bash

#===============================================================================
# Deploy Base and Core, then restart RKE2
#===============================================================================

source ".env"

echo
echo "Section: Deploy Base and Core, then restart RKE2"
#===============================================================================
kind delete cluster
kind create cluster --config kind-config.yaml

sleep 60

REPOSITORY=global-cloudwork/kubernetes
BRANCH=main

# Generate Authentik secret key
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 36)

# Install infrastructure + CRDs
kubectl kustomize --enable-helm \
  "github.com/$REPOSITORY/kubernetes?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -

kubectl create secret generic authentik-secret-key \
  --namespace authentik \
  --from-literal=secret_key="$AUTHENTIK_SECRET_KEY" \
  --dry-run=client -o yaml | \
  kubectl apply -f -

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

NAMESPACE="argocd"

echo "🔐 Fetching Argo CD credentials from namespace: $NAMESPACE"
echo ""

# Username is always admin for default install
echo "Username:"
echo "admin"
echo ""

# Get password from Kubernetes secret
echo "Password:"
kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

echo ""
echo ""
echo "🌐 UI (gateway access):"
echo "http://homepage.local/"
echo ""
echo "TLS note: If your gateway terminates TLS for homepage.local, use https://homepage.local/ (trust the gateway's certificate)."