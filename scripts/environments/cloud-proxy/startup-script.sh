#!/bin/bash
apt update -y
apt upgrade -y
apt install wireguard git -y

git config --global user.email "josh.v.mcconnell@gmail.com"
git config --global user.name "josh m"

sudo curl --silent --show-error -o /usr/local/bin/bootstrap https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/cloud-proxy/init-cloud-proxy.sh
sudo chmod 755 /usr/local/bin/bootstrap

# Install K9s
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb && apt install ./k9s_linux_amd64.deb
rm k9s_linux_amd64.deb