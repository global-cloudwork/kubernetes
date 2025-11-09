#!/bin/bash
set -euo pipefail

# Update and upgrade system packages
apt update -y
apt upgrade -y

# Prepare init directory (used by bootstrap/init scripts if needed)
mkdir -p /home/ubuntu/init

# Fetch bootstrap script for cloud proxy setup
cURL --silent --show-error -o /usr/local/bin/bootstrap https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/cloud-proxy/init-cloud-proxy.sh
chmod 755 /usr/local/bin/bootstrap
