#!/bin/bash
# Run as root
/usr/local/bin/rke2-killall.sh
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

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml


# kubectl apply -k https://github.com/kubernetes-sigs/gateway-api/config/crd
kubectl create namespace argocd
kubectl create namespace cert-manager
kubectl create secret tls ca -n default --key=../../keys/argocd-key.pem --cert=../../keys/argocd.localhost.pem

openssl genrsa -out argocd-key.pem 2048
openssl req -new -x509 -key argocd-key.pem -out argocd.localhost.pem -days 365 \
  -subj "/CN=argocd.localhost/O=argocd"
kubectl create secret tls argocd-tls \
  --cert=argocd.localhost.pem \
  --key=argocd-key.pem \
  -n argocd

