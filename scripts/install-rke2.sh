#!/bin/bash
echo "Install RKE2"
curl -sfL https://get.rke2.io | sudo sh -

mkdir -p /etc/rancher/rke2/
cp ../configurations/local-kubeconfig.yaml /etc/rancher/rke2/config.yaml

systemctl enable rke2-server.service
# systemctl start rke2-server.service
