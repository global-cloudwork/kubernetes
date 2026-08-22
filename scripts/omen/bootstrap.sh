#!/usr/bin/env bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/../env.sh"

ENV="dev"

echo
echo_header "Space Age GitOps Bootstrap - $ENV"
echo

AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY
GITHUB_USERNAME=$GITHUB_USERNAME
GITHUB_PAT_TOKEN=$GITHUB_PAT_TOKEN
REPOSITORY=$REPOSITORY
BRANCH=$BRANCH

# Dev: tear down and recreate cluster
if [[ "$ENV" == "dev" ]]; then
  echo_header "Creating Kind cluster..."
  kind delete cluster 2>/dev/null || true
  kind create cluster --config scripts/omen/kind-config.yaml
  echo_ok "Cluster created"
  sleep 60
fi

# Deploy infrastructure (namespaces, CRDs, etc)
echo_header "Deploying infrastructure and CRDs..."
kubectl kustomize --enable-helm "github.com/$REPOSITORY/kubernetes?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -
echo_ok "Infrastructure deployed"

# Deploy ArgoCD
echo_header "Deploying ArgoCD..."
kubectl kustomize --enable-helm "github.com/$REPOSITORY/applications/argocd?ref=$BRANCH" | \
  kubectl apply --server-side --force-conflicts -f -
sleep 60
echo_ok "ArgoCD deployed"

# Deploy bootstrap configuration (hydrator, secrets, applications)
echo_header "Configuring Space Age GitOps..."
helm template bootstrap \
  "helm/bootstrap" \
  -f "helm/bootstrap/values-$ENV.yaml" \
  --set authentik.secretKey="$AUTHENTIK_SECRET_KEY" \
  --set repository.username="$GITHUB_USERNAME" \
  --set repository.password="$GITHUB_PAT_TOKEN" | \
  kubectl apply --server-side --force-conflicts -f -
echo_ok "Space Age GitOps configured"

sleep 30
echo
echo_ok "Bootstrap complete"
echo "  ArgoCD UI: http://argocd.local/"
echo
exit 0
