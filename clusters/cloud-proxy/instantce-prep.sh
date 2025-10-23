#!/bin/bash
# Runs as root on first boot

# 1. Update system packages
apt update -y
apt upgrade

mkdir /home/ubuntu/init.sh
curl --silent --show-error -o /home/ubuntu/init.sh https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/init.sh
chmod 755 /home/ubuntu/init.sh