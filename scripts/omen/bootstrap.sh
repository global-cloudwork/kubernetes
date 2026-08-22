#!/usr/bin/env bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# Parse environment parameter
ENV="${1:-dev}"
if [[ ! "$ENV" =~ ^(dev|staging)$ ]]; then
  common_err "Usage: bootstrap.sh {dev|staging}"
  exit 1
fi

echo
common_header "Space Age GitOps Bootstrap - $ENV"
echo

# Declare all variables upfront with error handling
AUTHENTIK_SECRET_KEY="${AUTHENTIK_SECRET_KEY:-$(openssl rand -base64 36)}"
GITHUB_USERNAME="${GITHUB_USERNAME:?Error: GITHUB_USERNAME not set}"
GITHUB_PAT_TOKEN="${GITHUB_PAT_TOKEN:?Error: GITHUB_PAT_TOKEN not set}"
REPOSITORY="${REPOSITORY:-global-cloudwork/kubernetes}"
BRANCH="${BRANCH:-main}"

# Dev: tear down and recreate cluster
if [[ "$ENV" == "dev" ]]; then
  common_header "Creating Kind cluster..."
  kind delete cluster 2>/dev/null || true
  kind create cluster --config scripts/omen/kind-config.yaml
  common_ok "Cluster created"
  sleep 60
fi

# Deploy infrastructure (namespaces, CRDs, etc)
common_header "Deploying infrastructure and CRDs..."
kubectl kustomize --enable-helm "github.com/$REPOSITORY/kubernetes?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -
common_ok "Infrastructure deployed"

# Deploy ArgoCD
common_header "Deploying ArgoCD..."
kubectl kustomize --enable-helm "github.com/$REPOSITORY/applications/argocd?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -
sleep 60
common_ok "ArgoCD deployed"

# Deploy bootstrap configuration (hydrator, secrets, applications)
common_header "Configuring Space Age GitOps..."
helm template bootstrap \
  "helm/bootstrap" \
  -f "helm/bootstrap/values-$ENV.yaml" \
  --set authentik.secretKey="$AUTHENTIK_SECRET_KEY" \
  --set repository.username="$GITHUB_USERNAME" \
  --set repository.password="$GITHUB_PAT_TOKEN" | \
  kubectl apply --server-side --force-conflicts -f -
common_ok "Space Age GitOps configured"

sleep 30
echo
common_ok "Bootstrap complete"
echo "  ArgoCD UI: http://argocd.local/"
echo
exit 0
