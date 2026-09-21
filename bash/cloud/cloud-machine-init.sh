#!/usr/bin/env bash
set -euo pipefail

# GCE startup script. It prepares the host but deliberately waits for the
# operator's first login before bootstrapping the Kubernetes control plane.
REPOSITORY_URL="$(curl -fsS -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/metadata/GIT_REPOSITORY_URL)"
REPOSITORY_ROOT=/opt/kubernetes
BOOTSTRAP_PATH=/root/bootstrap-kubernetes.sh

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git docker.io
systemctl enable --now docker
usermod -aG docker google-sudoers 2>/dev/null || true

rm -rf "${REPOSITORY_ROOT}"
git clone --depth=1 "${REPOSITORY_URL}" "${REPOSITORY_ROOT}"
install -m 0755 "${REPOSITORY_ROOT}/bash/cloud/bootstrap-cloud-cluster.sh" "${BOOTSTRAP_PATH}"
touch /var/lib/cloud/kubernetes-host-ready

cat > /root/KUBERNETES-BOOTSTRAP.txt <<EOF
The host is ready. Before running /root/bootstrap-kubernetes.sh, provide the
GitHub App files expected by bootstrap.sh:
  GITHUB_APP_ID_FILE
  GITHUB_APP_INSTALLATION_ID_FILE
  GITHUB_APP_PRIVATE_KEY_FILE

The repository is checked out at ${REPOSITORY_ROOT}.
EOF
