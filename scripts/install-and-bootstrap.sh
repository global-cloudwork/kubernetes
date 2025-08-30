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
systemctl enable --now rke2-server.service

echo check if bin for rke2 is in path
if ! echo "$PATH" | grep -q "/var/lib/rancher/rke2/bin"; then
  echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.profile
  echo "reuslt - path needs to be added, profile modified"
else
  echo "result - path exists already, profile unchanged"
fi

ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
mkdir -p ~/.kube
ln -s /etc/rancher/rke2/rke2.yaml ~/.kube/config
export PATH=$PATH:/var/lib/rancher/rke2/bin/

# echo chmod a+r for testing purposes
# chmod a+r /etc/rancher/rke2/rke2.yaml

echo waiting for the node, then all of its pods
kubectl wait --for=condition=Ready node --all --timeout=600s

echo applying crds and other manifests /components/bootstrap 
kubectl kustomize "github.com/global-cloudwork/kubernetes/components/bootstrap?ref=main" | kubectl apply --wait --server-side --force-conflicts -f -

echo applying the argocd helm chart, turned manifest /components/applications/argocd
kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes/components/applications/argocd?ref=main" | kubectl apply --wait --server-side --force-conflicts -f -

echo applying the development kustomize overlay environments/development
kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes/components/environments/development?ref=main" | kubectl apply --server-side --force-conflicts -f -

#Token sudo cat /var/lib/rancher/rke2/server/node-token 