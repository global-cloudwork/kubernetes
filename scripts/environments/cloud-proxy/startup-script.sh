#!/bin/bash
apt update -y
apt upgrade
apt install curl -y

mkdir /home/ubuntu/init.sh
sudo curl --silent --show-error -o /usr/local/bin/bootstrap https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/cloud-proxy/init-cloud-proxy.sh
sudo chmod 755 /usr/local/bin/bootstrap