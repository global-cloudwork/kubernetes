#!/bin/bash
set -euo pipefail
apt-get update -y
apt-get upgrade -y
apt-get install -y curl

# Ensure compatibility for downstream scripts that call 'cURL'
if [ ! -x /usr/bin/cURL ] && [ -x /usr/bin/curl ]; then
	ln -sf /usr/bin/curl /usr/bin/cURL
fi

curl --silent --show-error -o /usr/local/bin/bootstrap https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/cloud-proxy/init-cloud-proxy.sh
chmod 755 /usr/local/bin/bootstrap