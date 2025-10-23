#!/bin/bash
apt update -y
apt upgrade

mkdir /home/ubuntu/init.sh
sudo curl --silent --show-error -o /usr/local/bin/bootstrap.sh https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/init.sh
sudo chmod 755 /usr/local/bin/init