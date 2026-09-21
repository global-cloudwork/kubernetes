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

Bootstraps the Kind cluster with Argo CD, cert-manager, and GitOps
Promoter. Promoter hydrates applications into the *-next branches and
promotes them through the active development, staging, and production
branches defined in kubernetes/promotion.

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
require_command helm

require_secret_file() {
  local name="$1"
  local path="${!name:-}"
  [[ -n "${path}" && -r "${path}" ]] || {
    echo_error "Required protected secret file is not readable: ${name}"
    exit 1
  }
}

require_secret_file GITHUB_APP_ID_FILE
require_secret_file GITHUB_APP_INSTALLATION_ID_FILE
require_secret_file GITHUB_APP_PRIVATE_KEY_FILE
GITHUB_APP_ID=$(<"${GITHUB_APP_ID_FILE}")
GITHUB_APP_INSTALLATION_ID=$(<"${GITHUB_APP_INSTALLATION_ID_FILE}")
GITHUB_APP_PRIVATE_KEY=$(<"${GITHUB_APP_PRIVATE_KEY_FILE}")

apply_manifest() {
  local path="$1"
  echo_header "Applying ${path}..."
  kubectl apply --server-side --force-conflicts -f "${REPOSITORY_ROOT}/${path}"
}

wait_for_deployment() {
  local namespace="$1"
  local name="$2"
  kubectl wait --for=condition=available --timeout=300s \
    "deployment/${name}" -n "${namespace}"
}

echo
echo_header "GitOps Bootstrap"
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

# The bootstrap boundary is deliberately explicit: these are the only
# resources installed before Argo CD starts reconciling the repository.
apply_manifest kubernetes/bootstrap/namespace.yaml

echo_header "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo update jetstack >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version 1.15.0 \
  --set crds.enabled=true \
  --set webhook.securePort=10260 \
  --set controller.securityContext.capabilities.add[0]=NET_RAW \
  --set controller.securityContext.capabilities.add[1]=NET_BIND_SERVICE
wait_for_deployment cert-manager cert-manager

echo_header "Installing Argo CD..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 9.1.0 \
  --set configs.params.server\.insecure=true \
  --set configs.params.hydrator\.enabled=true \
  --set configs.params.commit\.server=argocd-commit-server:8086 \
  --set commitServer.enabled=true
wait_for_deployment argocd argocd-server

# Install the platform controllers and initial ApplicationSet explicitly.
# The ApplicationSet then owns application reconciliation; it is not needed
# to install Argo CD itself.
kubectl apply --server-side --force-conflicts -f \
  https://github.com/argoproj-labs/gitops-promoter/releases/download/v0.40.1/install-with-dashboard-cert-manager.yaml

# Credentials are intentionally supplied through protected files and never
# stored in Git. Secret values are sent over kubectl stdin, not argv.
cat <<EOF | kubectl apply --server-side --force-conflicts -f -
apiVersion: v1
kind: Secret
metadata:
  name: global-cloudwork-kubernetes-write
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository-write
type: Opaque
stringData:
  type: git
  url: https://github.com/global-cloudwork/kubernetes
  githubAppID: ${GITHUB_APP_ID}
  githubAppInstallationID: ${GITHUB_APP_INSTALLATION_ID}
  githubAppPrivateKey: |
$(printf '%s\n' "${GITHUB_APP_PRIVATE_KEY}" | sed 's/^/    /')
EOF
cat <<EOF | kubectl apply --server-side --force-conflicts -f -
apiVersion: v1
kind: Secret
metadata:
  name: global-cloudwork-kubernetes
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/global-cloudwork/kubernetes
  githubAppID: ${GITHUB_APP_ID}
  githubAppInstallationID: ${GITHUB_APP_INSTALLATION_ID}
  githubAppPrivateKey: |
$(printf '%s\n' "${GITHUB_APP_PRIVATE_KEY}" | sed 's/^/    /')
EOF
cat <<EOF | kubectl apply --server-side --force-conflicts -f -
apiVersion: v1
kind: Secret
metadata:
  name: github-app
  namespace: promoter-system
type: Opaque
stringData:
  githubAppID: ${GITHUB_APP_ID}
  githubAppInstallationID: ${GITHUB_APP_INSTALLATION_ID}
  githubAppPrivateKey: |
$(printf '%s\n' "${GITHUB_APP_PRIVATE_KEY}" | sed 's/^/    /')
EOF

for manifest in \
  kubernetes/argocd/app-project.yaml \
  kubernetes/argocd/argocd-commit-status.yaml \
  kubernetes/argocd/application-set.yaml \
  kubernetes/gateway/gateway-class.yaml \
  kubernetes/gateway/gateway-certificate.yaml \
  kubernetes/gateway/gateway.yaml \
  kubernetes/gateway/ingress.yaml \
  kubernetes/repository/git-repository.yaml \
  kubernetes/repository/scm-provider.yaml \
  kubernetes/promotion/dependents-successful-commit-status.yaml \
  kubernetes/promotion/promotion-strategy.yaml; do
  apply_manifest "${manifest}"
done

echo
echo_ok "Bootstrap complete"
echo "  ArgoCD UI: http://argocd.local/"
echo
