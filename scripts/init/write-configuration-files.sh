#sudo journalctl -u google-startup-scripts.service --no-pager

# Static Configuration
HOST_IP=$(hostname -I | awk '{print $1}')
CLUSTER_NAME=cloud-proxy
DEFAULT_KUBECONFIG=$HOME/.kube/config
RKE2_KUBECONFIG=/etc/rancher/rke2/rke2.yaml
REVISION=main
REPOSITORY=global-cloudwork/kubernetes
RAW_REPOSITORY=https://raw.githubusercontent.com/$REPOSITORY/$REVISION
CLUSTER_INIT=true
FQDN=$(hostname -f)

# Values about the node, and it's cluster
NODE_ROLE=server
CLUSTER_ID=$(($CLUSTER_NAME + 0))
## RKE2 Configuration
RKE2_CONFIGURATION="
cni: cilium
write-kubeconfig-mode: \"0600\"
tls-sans:
  - \"localhost\"
debug: true"

## Cilium Configuration
CILIUM_CONFIGURATION="
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-cilium
  namespace: kube-system
spec:
  valuesContent: |-
    encryption:
      enabled: true
      type: wireguard
    kubeProxyReplacement: true
    k8sServiceHost: "127.0.0.1"
    k8sServicePort: "6443"
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

function h2() {
  command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}
function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

h2 "Create and write rke2 configuration files"
mkdir -p /etc/rancher/rke2
sudo touch /etc/rancher/rke2/config.yaml
sudo tee /etc/rancher/rke2/config.yaml <<< "$RKE2_CONFIGURATION"

h2 "Create and write cilium configuration files"
mkdir -p /var/lib/rancher/rke2/server/manifests
sudo touch /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml
sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml <<< "$CILIUM_CONFIGURATION"