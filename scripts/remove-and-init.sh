#!/bin/bash
# Run as root
/usr/local/bin/rke2-uninstall.sh

mkdir -p /var/lib/rancher/rke2/manifests/
mkdir -p /etc/rancher/rke2/

cp ../configurations/helm/cilium.yaml /var/lib/rancher/rke2/manifests/cilium-helm-overlay.yaml
cp ../configurations/other/etc-rancher-rke2-config.yaml /etc/rancher/rke2/config.yaml

curl -sfL https://get.rke2.io | sudo sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml

kubectl create namespace argocd

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
  | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes?ref=development" \
  | kubectl apply -f -

kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

kubectl port-forward svc/argocd-server -n argocd 8080:443

kubectl get secret argocd-tls-cert -n argocd -o jsonpath='{.data.tls\.crt}' | base64 -d > argocd.crt
sudo cp argocd.crt /usr/local/share/ca-certificates/argocd.crt
sudo update-ca-certificates
