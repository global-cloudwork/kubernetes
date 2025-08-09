#!/bin/bash

export PS1='\u in \W: '
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

for file in ../../bootstrap/init/*.yaml; do
  echo "Applying $file"
  kubectl apply -f "$file"
done
