#!/bin/bash
# Runs as root on first boot

# 1. Update system packages
apt update -y
apt upgrade

mkdir /home/ubuntu/init.sh
sudo curl --silent --show-error -o /usr/local/bin/init.sh https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/init.sh
sudo chmod 755 /home/ubuntu/init.sh