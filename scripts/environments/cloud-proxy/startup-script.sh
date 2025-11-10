#!/bin/bash

CURRENT_KERNEL=$(uname -r)

apt-get update -qq
apt-get upgrade -y -qq
apt-get install wireguard git -y -qq

sudo curl --silent --show-error -o /usr/local/bin/bootstrap https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/cloud-proxy/init-cloud-proxy.sh
sudo chmod 755 /usr/local/bin/bootstrap

# Install K9s
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb && apt install ./k9s_linux_amd64.deb -y -qq
rm k9s_linux_amd64.deb