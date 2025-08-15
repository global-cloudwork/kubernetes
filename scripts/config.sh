
kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/tools?ref=development" \
  | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/cilium?ref=development" \
  | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/applications/core/argocd?ref=development" \
  | kubectl apply -f -

# sudo chmod a+r /etc/rancher/rke2/rke2.yaml