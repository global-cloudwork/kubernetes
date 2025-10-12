#sudo journalctl -u google-startup-scripts.service --no-pager
#sudo systemctl status rke2-server.service

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

# For enviroment variable substitution
PATH=$PATH:/opt/rke2/bin
HOST_IP=$(hostname -I | awk '{print $1}')
CLUSTER_NAME=cloud-proxy
CLUSTER_ID=$(($CLUSTER_NAME + 0))

# Values passed to the startup script using encrypted metadata
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" $EXTERNAL_IP)

h1 "Configure RKE2 & Deploy Kustomizations"

h2 "apt update & install"
sudo apt-get update
sudo apt-get install -y git

h2 "Curl and install rke2, helm, and k9s"
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sfL https://get.rke2.io | sudo sh -

h2 "Create and write rke2 configuration files"
sudo mkdir -p /etc/rancher/rke2
curl -sL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/configurations/rke2.yaml \
  | envsubst | sudo tee /etc/rancher/rke2/config.yaml > /dev/null

h2 "Create and write cilium configuration file, and crds"
sudo mkdir -p /var/lib/rancher/rke2/server/manifests

# Cilium Helm Chart Config with Gateway API enabled 
curl -sL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/configurations/cilium.yaml \
  | envsubst | sudo tee /var/lib/rancher/rke2/server/manifests/rke2-cilium-config.yaml > /dev/null

# Gateway API CRDs
curl -sSL https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/gateway.networking.k8s.io_gatewayclasses.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/gateway.networking.k8s.io_gateways.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/gateway.networking.k8s.io_grpcroutes.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/gateway.networking.k8s.io_httproutes.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/gateway.networking.k8s.io_referencegrants.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/gateway.networking.k8s.io_tlsroutes.yaml > /dev/null

# Argo CD CRDs
curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/applicationset-crd.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/applicationset-crd.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/application-crd.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/application-crd.yaml > /dev/null
curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.0/manifests/crds/appproject-crd.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/appproject-crd.yaml > /dev/null

# Cert-Manager CRDs
curl -sSL -L https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml | sudo tee /var/lib/rancher/rke2/server/manifests/cert-manager.crds.yaml > /dev/null

# h2 "setting up kubectl"
sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl

h2 "check for if Path does not contain /var/lib/rancher/rke2/bin append"
export PATH=/var/lib/rancher/rke2/bin:$PATH

h2 "Enable, then start the rke2-server service"
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

declare -a KUSTOMIZE_PATHS=(
  "components/bootstrap"
  "components/applications/argocd"
  "components/environments/development"
)

h1 "Replacing kubeconfig"
curl -sS https://webinstall.dev/k9s | bash
source ~/.config/envman/PATH.env

h2 "Getting environment variables from Secret Manager"
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

h2 "create kubeconfig directory"
mkdir -p $HOME/.kube/$CLUSTER_NAME

h2 "copying kubeconfig"
sudo mkdir -p /home/ubuntu/.kube/cloud-proxy
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/cloud-proxy/config

h2 "find and flatten the configs in files like HOME/.kube/*/config"
KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
kubectl --kubeconfig="$KUBECONFIG_LIST" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

h2 "waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=100s --insecure-skip-tls-verify
kubectl wait --for=condition=Ready pods --all --timeout=100s --insecure-skip-tls-verify

# h2 "deleting pods to enable cilium hostNetwork"
# kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true | grep '<none>' | awk '{print "-n "$1" "$2}' | xargs -L 1 -r kubectl delete pod

h2 "waiting for the node, then all of its pods"
kubectl wait --for=condition=Ready node --all --timeout=100s
kubectl wait --for=condition=Ready pods --all --timeout=100s

for CURRENT_PATH in "${KUSTOMIZE_PATHS[@]}"; do
    h2 "Applying Kustomize PATH: $CURRENT_PATH"
    kubectl kustomize --enable-helm "github.com/$REPOSITORY/$CURRENT_PATH?ref=$BRANCH" | \
      kubectl apply --server-side --force-conflicts -f -
    
    h2 "sleeping 10s to allow resources to settle"
    sleep 10
done