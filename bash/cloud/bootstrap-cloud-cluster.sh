#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="${REPOSITORY_ROOT:-/opt/kubernetes}"
SECRET_DIR="${SECRET_DIR:-/root/kubernetes-secrets}"

if [[ ! -d "${REPOSITORY_ROOT}/.git" ]]; then
  printf 'Repository checkout not found at %s\n' "${REPOSITORY_ROOT}" >&2
  exit 1
fi

for command in kind kubectl helm; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    case "${command}" in
      kind) curl -fsSL https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64 -o /usr/local/bin/kind; chmod 0755 /usr/local/bin/kind ;;
      kubectl) curl -fsSLo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl; chmod 0755 /usr/local/bin/kubectl ;;
      helm) curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash ;;
    esac
  fi
done

export GITHUB_APP_ID_FILE="${GITHUB_APP_ID_FILE:-${SECRET_DIR}/github-app-id}"
export GITHUB_APP_INSTALLATION_ID_FILE="${GITHUB_APP_INSTALLATION_ID_FILE:-${SECRET_DIR}/github-app-installation-id}"
export GITHUB_APP_PRIVATE_KEY_FILE="${GITHUB_APP_PRIVATE_KEY_FILE:-${SECRET_DIR}/github-app-private-key}"
cd "${REPOSITORY_ROOT}"
exec bash bash/omen/bootstrap.sh "$@"
