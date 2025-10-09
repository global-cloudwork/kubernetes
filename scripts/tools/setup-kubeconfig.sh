# gcloud compute ssh ubuntu@cloud-proxy \
#     --project=global-cloudworks \
#     --zone=us-central1-a \
#     --command='curl -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tools/setup-kubeconfig.sh | bash'


#curl -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tools/setup-kubeconfig.sh | bash
function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

h1 "Replacing kubeconfig"

h2 "copying kubeconfig"
sudo mkdir -p /home/ubuntu/.kube/cloud-proxy
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/cloud-proxy/config

h2 "Find and flatten csv of clusters stored in $KUBECONFIG"
KUBECONFIG=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
sudo kubectl --kubeconfig="$KUBECONFIG" config view --flatten > /home/ubuntu/.kube/config
