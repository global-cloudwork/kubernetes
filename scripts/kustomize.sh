#!/bin/bash
kubectl create secret tls argocd-server-tls -n argocd --key=../../keys/argocd-key.pem --cert=../../keys/argocd.localhost.pem

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
chmod 644 /etc/rancher/rke2/rke2.yaml

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes?ref=development" \
  | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/kubernetes/connection?ref=development" \
  | kubectl apply -f -

kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8080:443

kubectl get secret argocd-tls-cert -n argocd -o jsonpath='{.data.tls\.crt}' | base64 -d > argocd.crt
sudo cp argocd.crt /usr/local/share/ca-certificates/argocd.crt
sudo update-ca-certificates