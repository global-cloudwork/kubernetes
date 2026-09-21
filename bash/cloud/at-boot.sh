#!/usr/bin/env bash
set -euo pipefail

# GCE startup script. Clone the repository and make the login bootstrap
# available for the operator to run after connecting to the instance.
REPOSITORY_URL="$(curl -fsS -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/metadata/GIT_REPOSITORY_URL)"
REPOSITORY_ROOT=/opt/kubernetes
LOGIN_SCRIPT=/root/at-login.sh

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git

rm -rf "${REPOSITORY_ROOT}"
git clone --depth=1 "${REPOSITORY_URL}" "${REPOSITORY_ROOT}"
install -m 0755 "${REPOSITORY_ROOT}/bash/cloud/at-login.sh" "${LOGIN_SCRIPT}"
