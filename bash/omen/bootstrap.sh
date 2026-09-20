#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPOSITORY_ROOT}/bash/env.sh"

apply_kustomization() {
  local path="$1"
  echo_header "Applying ${path}..."
  kubectl kustomize --enable-helm "${REPOSITORY_ROOT}/${path}" |
    kubectl apply --server-side --force-conflicts -f -
}

wait_for_deployment() {
  local namespace="$1"
  local name="$2"
  kubectl wait --for=condition=available --timeout=300s \
    "deployment/${name}" -n "${namespace}"
}

echo
echo_header "Kustomize GitOps Bootstrap"
echo

echo_header "Deleting Kind cluster..."
kind delete cluster 2>/dev/null || true

echo_header "Creating Kind cluster..."
kind create cluster --config "${REPOSITORY_ROOT}/bash/omen/kind-config.yaml"

echo_header "Applying namespaces..."
kubectl apply --server-side --force-conflicts -f "${REPOSITORY_ROOT}/namespace.yaml"

# Install cert-manager before the Promoter bundle, which uses cert-manager
# to issue the dashboard API serving certificate.
apply_kustomization applications/cert-manager
wait_for_deployment cert-manager cert-manager

# Argo CD includes the Source Hydrator controller used by the ApplicationSet.
apply_kustomization applications/argocd
wait_for_deployment argocd argocd-server

# The ApplicationSet in core generates the application deployments. Promoter
# then advances their hydrated manifests through the environment branches.
apply_kustomization kubernetes/core

echo
echo_ok "Bootstrap complete"
echo "  ArgoCD UI: http://argocd.local/"
echo
