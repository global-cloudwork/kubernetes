#!/bin/bash
apt update -y
apt upgrade

mkdir /home/ubuntu/init.sh
sudo curl --silent --show-error -o /usr/local/bin/bootstrap https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/init.sh
sudo chmod 755 /usr/local/bin/bootstrap

# Install K9s
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb && apt install ./k9s_linux_amd64.deb
rm k9s_linux_amd64.deb