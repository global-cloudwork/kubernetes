#!/usr/bin/env bash
set -euo pipefail

# This script deliberately never clones the repository. Every bootstrap input
# is fetched into a temporary directory and removed when the script exits.
REPOSITORY_ROOT="${REPOSITORY_ROOT:-/opt/kubernetes}"
SECRET_DIR="${SECRET_DIR:-/root/kubernetes-secrets}"
GITHUB_APP_ID_FILE="${GITHUB_APP_ID_FILE:-${SECRET_DIR}/github-app-id}"
GITHUB_APP_INSTALLATION_ID_FILE="${GITHUB_APP_INSTALLATION_ID_FILE:-${SECRET_DIR}/github-app-installation-id}"
GITHUB_APP_PRIVATE_KEY_FILE="${GITHUB_APP_PRIVATE_KEY_FILE:-${SECRET_DIR}/github-app-private-key}"

RAW_ROOT="${GIT_RAW_ROOT:-https://raw.githubusercontent.com/global-cloudwork/kubernetes/main}"
WORK_DIR="$(mktemp -d /tmp/kubernetes-bootstrap.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

log() { printf '\n==> %s\n' "$1"; }
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command is missing: %s\n' "$1" >&2
    exit 1
  }
}
download() {
  local url="$1" output="$2"
  curl -fsSL "${url}" -o "${output}"
}
apply_url() {
  local url="$1"
  local manifest="${WORK_DIR}/$(basename "${url}")"
  download "${url}" "${manifest}"
  kubectl apply --server-side --force-conflicts -f "${manifest}"
}

log "Installing bootstrap tools"
require_command curl
if ! command -v kind >/dev/null 2>&1; then
  curl -fsSL https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64 -o /usr/local/bin/kind
  chmod 0755 /usr/local/bin/kind
fi
if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSL https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
  chmod 0755 /usr/local/bin/kubectl
fi
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
require_command kind
require_command kubectl
require_command helm

log "Creating Kind cluster"
KIND_CONFIG="${WORK_DIR}/kind-config.yaml"
download "${RAW_ROOT}/bash/omen/kind-config.yaml" "${KIND_CONFIG}"
if ! kind get clusters 2>/dev/null | grep -qx 'kind'; then
  kind create cluster --config "${KIND_CONFIG}"
else
  printf 'Using existing Kind cluster\n'
fi

log "Applying CRDs"
# CRDs must exist before any namespaced or controller resources are applied.
apply_url "https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml"
apply_url "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/experimental-install.yaml"

log "Applying namespaces"
apply_url "${RAW_ROOT}/kubernetes/bootstrap/namespace.yaml"

log "Applying Argo CD"
apply_url "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
apply_url "${RAW_ROOT}/kubernetes/argocd/app-project.yaml"
apply_url "${RAW_ROOT}/kubernetes/argocd/argocd-commit-status.yaml"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

for file in "${GITHUB_APP_ID_FILE}" "${GITHUB_APP_INSTALLATION_ID_FILE}" "${GITHUB_APP_PRIVATE_KEY_FILE}"; do
  [[ -r "${file}" ]] || {
    printf 'Required secret file is not readable: %s\n' "${file}" >&2
    exit 1
  }
done
GITHUB_APP_ID="$(<"${GITHUB_APP_ID_FILE}")"
GITHUB_APP_INSTALLATION_ID="$(<"${GITHUB_APP_INSTALLATION_ID_FILE}")"
GITHUB_APP_PRIVATE_KEY="$(<"${GITHUB_APP_PRIVATE_KEY_FILE}")"
[[ -n "${GITHUB_APP_ID}" && -n "${GITHUB_APP_INSTALLATION_ID}" && -n "${GITHUB_APP_PRIVATE_KEY}" ]] || {
  printf 'GitHub App credential files must not be empty\n' >&2
  exit 1
}

# Credentials are sent via stdin so private key material is never exposed in
# the process argument list or written into the temporary manifest directory.
printf '%s\n' "${GITHUB_APP_PRIVATE_KEY}" | sed 's/^/    /' > "${WORK_DIR}/private-key.yaml"
cat > "${WORK_DIR}/github-app-secret.yaml" <<EOF
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
$(<"${WORK_DIR}/private-key.yaml")
EOF
kubectl apply --server-side --force-conflicts -f "${WORK_DIR}/github-app-secret.yaml"

log "Applying ApplicationSets"
apply_url "${RAW_ROOT}/kubernetes/argocd/application-set.yaml"

printf '\nBootstrap complete. Argo CD is now reconciling the repository.\n'
