#!/bin/bash
echo "Install RKE2"
sudo curl -sfL https://get.rke2.io | sudo sh -

mkdir -p /etc/rancher/rke2/
cp ../configurations/local-kubeconfig.yaml /etc/rancher/rke2/config.yaml

systemctl enable rke2-server.service
systemctl start rke2-server.service

echo "Waiting for kubeconfig..."
while [ ! -f /etc/rancher/rke2/rke2.yaml ]; do
    sleep 2
done

# Link kubeconfig after it’s ready
chmod 644 /etc/rancher/rke2/rke2.yaml