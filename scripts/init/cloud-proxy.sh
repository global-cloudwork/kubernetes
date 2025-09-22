#sudo journalctl -u google-startup-scripts.service --no-pager

# Static Configuration
CLUSTER_NAME=cloud-proxy
DEFAULT_KUBECONFIG=$HOME/.kube/config
RKE2_KUBECONFIG=/etc/rancher/rke2/rke2.yaml
REVISION=main
REPOSITORY=global-cloudwork/kubernetes
RAW_REPOSITORY=https://raw.githubusercontent.com/$REPOSITORY/$REVISION

# Values passed to the startup script using encrypted metadata
AUTHORS_PUBLIC_KEY=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/attributes/public-key)
AUTHORS_IP=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/attributes/allowed-ips)
CILIUM_CA=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/attributes/cilium-ca)
ADDRESS=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip) 

# Values about the node, and it's cluster
NODE_ROLE=server
CLUSTER_ID=$(($CLUSTER_NAME + 0))
## RKE2 Configuration
RKE2_CONFIGURATION="
disable-kube-proxy: true
etcd-expose-metrics: false
cni: cilium
write-kubeconfig-mode: '0644'
tls-san:
 - $HOST_IP
node-name: $CLUSTER_NAME
tls-san:
  - $HOST_IP"
echo "define additions to the file"
## Cilium Configuration
CILIUM_CONFIGURATION= "
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    kubeProxyReplacement: true
    k8sServiceHost: $ADDRESS
    k8sServicePort: 6443
    operator:
      replicas: 1
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
        service: 
          type: NodePort
    cluster:
      name: $CLUSTER_NAME
      id: $CLUSTER_ID"


#Environment Variables - Cluster & Composition
declare -a PEERS=(
    "${AUTHORS_PUBLIC_KEY},${AUTHORS_IP}"
)
declare -a KUSTOMIZE_PATHS=(
  "components/bootstrap"
  "components/applications/argocd"
  "components/environments/development"
)

function h2() {
  command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}
function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

h1 "Configure RKE2 & Deploy Kustomizations"

h2 "apt installing curl"
sudo apt-get update
sudo apt-get install -y curl git wireguard

h2 "Setting up headscale configuration."
sudo mkdir -p /etc/headscale
sudo curl -o /etc/headscale/config.yaml https://raw.githubusercontent.com/juanfont/headscale/v0.26.1/config-example.yaml

curl the following in to this location /etc/headscale
curl -o config.yaml https://raw.githubusercontent.com/juanfont/headscale/v0.26.1/config-example.yaml

h2 "Curl and install rke2, helm, and k9s"
# curl -sS https://webinstall.dev/k9s | bash
# curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sfL https://get.rke2.io | sudo sh -

h2 "Create and write configuration files"
mkdir -p /var/lib/rancher/rke2/server/manifests
mkdir -p /etc/rancher/rke2
touch /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
touch /etc/rancher/rke2/config.yaml
echo "$CILIUM_CONFIGURATION" | sudo tee -a /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null
echo "$RKE2_CONFIGURATION" | sudo tee -a /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null

h2 "Enable, then start the rke2-server service"
sudo systemctl enable --now rke2-server.service

while [ ! -f /etc/rancher/rke2/rke2.yaml ]; do
  h2 "kubeconfig not found yet, waiting"
  sleep 5
done

h2 "setting up kubectl"
sudo cp /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
sudo chown "$USER":"$USER" /usr/local/bin/kubectl
PATH=$PATH:/var/lib/rancher/rke2/bin/

h2 "making kubeconfig directories"
mkdir -p "$HOME/.kube/$CLUSTER_NAME"

h2 "linking kubeconfig to subfolder, and merging all kubeconfigs into default location"
cp /etc/rancher/rke2/rke2.yaml "$HOME/.kube/$CLUSTER_NAME/config"
chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"
export KUBECONFIG=$(find "$HOME/.kube/" \( -type f -o -type l \) -name config | paste -sd:)

# Flatten all merged kubeconfigs into the default config file
kubectl config view --flatten > "$HOME/.kube/config"

h2 "waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=100s
kubectl wait --for=condition=Ready pods --all --timeout=100s

# h2 "deleting pods to enable cilium hostNetwork"
# kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true | grep '<none>' | awk '{print "-n "$1" "$2}' | xargs -L 1 -r kubectl delete pod

h2 "waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=100s
kubectl wait --for=condition=Ready pods --all --timeout=100s

for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    h2 "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$REVISION" | \
      kubectl apply --server-side --force-conflicts -f -
    kubectl wait --for=condition=complete jobs --all -A --timeout=100s || true
    kubectl wait --for=condition=running pods --all -A --timeout=100s || true
done

# echo "STARTUP COMPLETE Starting Wireguard Setup"

# h2 "Generate Wireguard Keys, Curl and decrypt metadata, and set variables"
# wg genkey > private.key
# wg pubkey < private.key > public.key
# PRIVATE_KEY=$(cat private.key)
# touch wireguard-configuration.config
# append_lines_to_file wireguard-configuration.config "
# [Interface]
# Address = $ADDRESS
# PrivateKey = $PRIVATE_KEY
# ListenPort = 51820
# SaveConfig = true"

# h2 "for each peer, create a new section in the wireguard-configuration.config"
# for peer in "${PEERS[@]}"; do
#     IFS=',' read -r public_key allowed_ips <<< "$peer"
#     append_lines_to_file wireguard-configuration.config "
#     [Peer]
#     PublicKey = $public_key
#     AllowedIPs = $allowed_ips"
# done

# wg setconf wg0 wireguard-configuration.conf
# ip link set up dev wg0



# # Conditional block to run only if CLUSTER_NAME is "cloud-proxy"
# if [ "$CLUSTER_NAME" == "cloud-proxy" ]; then
#   # Download and apply Cilium CA
#   curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/cilium-ca \
#   | base64 -d | kubectl create -f -

#     # Commented-out secret creation (as in the original code)
#     # kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.example.com.pem
# fi




# kubectl create secret tls argocd-server-tls -n argocd --key=argocd-key.pem --cert=argocd.example.com.pem
