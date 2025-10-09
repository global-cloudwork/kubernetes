
h1 "Replacing kubeconfig"

h2 "copying kubeconfig"
sudo cp -f /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/cloud-proxy/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/cloud-proxy/config

h2 "Find and flatten csv of clusters stored in $KUBECONFIG"
KUBECONFIG=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)
kubectl --kubeconfig="$KUBECONFIG" config view --flatten > /home/ubuntu/.kube/config
