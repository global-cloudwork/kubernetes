#!/usr/bin/env bash
set -euo pipefail

curl -fsSL \
  https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/bash/cloud/at-login.sh \
  -o /root/at-login.sh
chmod +x /root/at-login.sh
