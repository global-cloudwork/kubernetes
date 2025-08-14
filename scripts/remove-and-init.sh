#!/bin/bash
# Run as root
/usr/local/bin/rke2-uninstall.sh

curl -sfL https://get.rke2.io | sudo sh -

mkdir -p /etc/rancher/rke2/
mkdir -p /var/lib/rancher/rke2/server/manifests/

cp ../configurations/etc-rancher-rke2-config.yaml /etc/rancher/rke2/config.yaml
cp ../applications/core/cilium/helm-chart-config.crd.yaml /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml

systemctl enable rke2-server.service
systemctl start rke2-server.service

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml