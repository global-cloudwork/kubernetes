#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly RESET='\033[0m'

echo_header() { printf '%b▶%b %s\n' "${BLUE}" "${RESET}" "$1"; }
echo_ok() { printf '%b✓%b %s\n' "${GREEN}" "${RESET}" "$1"; }
echo_error() { printf '%b✗%b %s\n' "${RED}" "${RESET}" "$1" >&2; }

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [--reset]

Bootstraps a local Kind cluster with Argo CD, cert-manager, and GitOps
Promoter. Promoter hydrates applications into the *-next branches and
promotes them through the active development, staging, and production
branches defined in kubernetes/core.

Options:
  --reset  Delete and recreate the Kind cluster before applying manifests.
  -h, --help  Show this help.
USAGE
}

RESET_CLUSTER=false
while (($#)); do
  case "$1" in
    --reset) RESET_CLUSTER=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo_error "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
  shift
done

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo_error "Required command not found: $1"
    exit 1
  }
}

require_command kind
require_command kubectl

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

if [[ "${RESET_CLUSTER}" == true ]]; then
  echo_header "Deleting Kind cluster..."
  kind delete cluster 2>/dev/null || true
fi

if ! kind get clusters 2>/dev/null | grep -qx 'kind'; then
  echo_header "Creating Kind cluster..."
  kind create cluster --config "${REPOSITORY_ROOT}/bash/omen/kind-config.yaml"
else
  echo_ok "Using existing Kind cluster"
fi

# Namespaces are applied first so the infrastructure charts can create their
# namespaced resources deterministically.
apply_kustomization kubernetes/bootstrap

# Install cert-manager before the Promoter bundle, which uses cert-manager
# to issue the dashboard API serving certificate.
apply_kustomization applications/cert-manager
wait_for_deployment cert-manager cert-manager

# Argo CD includes the Source Hydrator controller used by the ApplicationSet.
apply_kustomization applications/argocd
wait_for_deployment argocd argocd-server

# The ApplicationSet generates one hydrated and one active Application per
# app/environment. Promoter writes to each *-next branch, then auto-merges
# development and staging while production remains an approval gate.
apply_kustomization kubernetes/core

echo
echo_ok "Bootstrap complete"
echo "  ArgoCD UI: http://argocd.local/"
echo
