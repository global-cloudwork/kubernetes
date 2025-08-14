#!/bin/bash
# Run as root
/usr/local/bin/rke2-uninstall.sh

mkdir -p /etc/rancher/rke2/

cp ../configurations/etc-rancher-rke2-config.yaml /etc/rancher/rke2/config.yaml

curl -sfL https://get.rke2.io | sudo sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml

kubectl create namespace argocd
kubectl create namespace cert-manager

kubectl apply -k https://github.com/kubernetes-sigs/gateway-api/config/crd
kubectl apply -f ../applications/core/cilium/helm-chart-config.crd.yaml