#!/bin/bash
#curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo Script Start - Configure a new RKE2 instilation, deploy manifests

echo curl and run installer script https://get.rke2.io
curl -sfL https://get.rke2.io | sudo sh -

echo copying startup configuration file in to place, then appending machines hostname
mkdir -p /etc/rancher/rke2/
sudo cp ../configurations/local.yaml /etc/rancher/rke2/config.yaml
echo -e '\nTls-san:\n  - $(hostname -f)' >> /etc/rancher/rke2/config.yaml

echo copying HelmChartConfig manifests in to place 
sudo mkdir -p /var/lib/rancher/rke2/server/manifests
sudo cp ../configurations/helm-chart-config.k8s.yaml /var/lib/rancher/rke2/server/manifests/

echo enable, then start the rke2-server service
systemctl enable rke2-server.service
systemctl start rke2-server.service

echo check if bin for rke2 is in path
if ! echo "$PATH" | grep -q "/var/lib/rancher/rke2/bin"; then
  echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.profile
  echo "reuslt - path needs to be added, profile modified"
else
  echo "result - path exists already, profile unchanged"
fi

echo export kubeconfig, and chmod a+r for testing purposes
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod a+r /etc/rancher/rke2/rke2.yaml

echo waiting for the node, then all of its pods
kubectl wait --for=condition=Ready node --all --timeout=600s

echo applying crds and other manifests /components/bootstrap 
kubectl kustomize "github.com/global-cloudwork/kubernetes/components/bootstrap?ref=main" | kubectl apply --wait --server-side --force-conflicts -f -

echo applying the argocd helm chart, turned manifest /applications/argocd
kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes/applications/argocd?ref=main" | kubectl apply --wait --server-side --force-conflicts -f -

echo applying the development kustomize overlay environments/development
kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes/components/environments/development?ref=main" | kubectl apply --server-side --force-conflicts -f -
