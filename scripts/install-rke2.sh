#!/bin/bash
echo "Install RKE2"
curl -sfL https://get.rke2.io | sudo sh -

mkdir -p /etc/rancher/rke2/
cp ../configurations/local-kubeconfig.yaml /etc/rancher/rke2/config.yaml

echo -e "\nnode-ip: \"$(hostname -I | awk '{print $1}')\"" | sudo tee -a /etc/rancher/rke2/config.yaml

systemctl enable rke2-server.service
systemctl start rke2-server.service

if ! echo "$PATH" | grep -q "/var/lib/rancher/rke2/bin"; then
  echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" >> ~/.profile
  echo "Added /var/lib/rancher/rke2/bin to PATH in ~/.profile"
else
  echo "/var/lib/rancher/rke2/bin is already in PATH"
fi