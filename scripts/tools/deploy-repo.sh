#!/usr/bin/env bash
# gcloud compute ssh ubuntu@cloud-proxy \
#     --project=global-cloudworks \
#     --zone=us-central1-a \
#     --command='curl -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tools/setup-kubeconfig.sh | bash'


#curl -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tools/deploy-repo.sh | bash
function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

declare -a KUSTOMIZE_PATHS=(
  "components/bootstrap"
  "components/applications/argocd"
  "components/environments/development"
)

h1 "Replacing kubeconfig"

h2 "Getting environment variables from Secret Manager"
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)

h2 "create kubeconfig directory"
mkdir -p $HOME/.kube/$CLUSTER_NAME

h2 "copying kubeconfig"
sudo mkdir -p /home/ubuntu/.kube/cloud-proxy
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/cloud-proxy/config

h2 "find and flatten csv of clusters stored in $KUBECONFIG"
KUBECONFIG=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
kubectl --kubeconfig="$KUBECONFIG" config view --flatten | sudo tee /home/ubuntu/.kube/config > /dev/null

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
    kubectl wait --for=condition=complete jobs --all -A --timeout=100s || true
    kubectl wait --for=condition=running pods --all -A --timeout=100s || true
done