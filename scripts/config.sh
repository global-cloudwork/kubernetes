kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.3.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes/tools?ref=development" \
#   | kubectl apply -f -

# kubectl kustomize --enable-helm \
#   "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
#   | kubectl apply -f -

# # sudo chmod a+r /etc/rancher/rke2/rke2.yaml