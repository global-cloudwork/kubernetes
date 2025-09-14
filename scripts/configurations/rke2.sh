CLUSTER_NAME="$1"
RAW_REPOSITORY="$2"
NODE_ROLE="${3:-server}"
RKE2_URL="${4:-}"          # Server URL
NODE_LABEL="${5:-}"        # Node label
NODE_TAINT="${6:-}"        # Node taint
HOST_IP=$(hostname -I | awk '{print $1}')

echo "Downloading rke2-configuration.yaml from base directory..."
sudo curl $RAW_REPOSITORY/clusters/base/rke2-configuration.yaml \
  --create-dirs --output /etc/rancher/rke2/config.yaml

echo "Define additions to the file"
LINES_TO_ADD="
write-kubeconfig-mode: '0644'
tls-san:
 - $HOST_IP
node-name: $CLUSTER_NAME
tls-san:
  - $HOST_IP"

if [ "$NODE_ROLE" = "server" ]; then
    echo "Node is server, applying current additions to the configuration returning."
    echo "$LINES_TO_ADD" | sudo tee -a /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null
    exit 0
fi

echo "node is agent, continue configurations"
echo "Apply agent specific configurations"
AGENT_LINES="
server: ${RKE2_URL:-}
node-label: ${NODE_LABEL:-}
node-taint: ${NODE_TAINT:-}
"
echo "$LINES_TO_ADD" | sudo tee -a /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null
echo "$AGENT_LINES" | sudo tee -a /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null
