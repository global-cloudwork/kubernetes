#!/bin/bash

export PS1='\u in \W: '
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

for file in ../../bootstrap/init/*.yaml; do
  echo "Applying $file"
  kubectl apply -f "$file"
done

# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.7.2/manifests/install.yaml
# kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

