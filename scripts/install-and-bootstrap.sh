#!/bin/bash
echo "Install RKE2"
curl -sfL https://get.rke2.io | sudo sh -

mkdir -p /etc/rancher/rke2/
sudo cp ../configurations/local.yaml /etc/rancher/rke2/config.yaml
echo -e '\nTls-san:\n  - $(hostname -f)' >> /etc/rancher/rke2/config.yaml

sudo mkdir -p /var/lib/rancher/rke2/server/manifests
sudo cp ../configurations/helm-chart-config.k8s.yaml /var/lib/rancher/rke2/server/manifests/

systemctl enable rke2-server.service
systemctl start rke2-server.service

if ! echo "$PATH" | grep -q "/var/lib/rancher/rke2/bin"; then
  echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.profile
  echo "Added /var/lib/rancher/rke2/bin to PATH in ~/.profile"
else
  echo "/var/lib/rancher/rke2/bin is already in PATH"
fi

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod a+r /etc/rancher/rke2/rke2.yaml

/var/lib/rancher/rke2/bin/kubectl wait --for=condition=Ready nodes --all --timeout=300s

kubectl kustomize --enable-helm \"github.com/global-cloudwork/kubernetes/kubernetes/bootstrap?ref=main\" | kubectl apply --server-side --force-conflicts -f -

kubectl wait --for=condition=Ready nodes --all --timeout=300s

kubectl kustomize --enable-helm \"github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=main\" | kubectl apply --server-side --force-conflicts -f -
