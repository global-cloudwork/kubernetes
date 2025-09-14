#!/bin/bash
CLUSTER_NAME="$1"
RAW_REPOSITORY="$2"
CLUSTER_ID=$(($CLUSTER_NAME + 0))

echo "Downloading cilium-configuration.yaml from base directory..."
sudo curl -sSL "$RAW_REPOSITORY/clusters/base/cilium-configuration.yaml" \
  --create-dirs --output /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml

echo "define additions to the file"
LINES_TO_ADD= "
    cluster:
      name: "$CLUSTER_NAME"
      id: $CLUSTER_ID"

echo "$LINES_TO_ADD" | sudo tee -a /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null