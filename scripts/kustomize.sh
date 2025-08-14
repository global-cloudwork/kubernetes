#!/bin/bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes?ref=development" \
  | kubectl apply -f -

