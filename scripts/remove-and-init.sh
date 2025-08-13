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
kubectl create cert-manager argocd

# kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.localhost.pem
# kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.18.0/examples/kubernetes/servicemesh/ca-issuer.yaml

kubectl apply -k https://github.com/kubernetes-sigs/gateway-api/config/crd