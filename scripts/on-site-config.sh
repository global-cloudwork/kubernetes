# sudo --preserve-env=KUBECONFIG ./on-site-config.sh

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes/tools?ref=development" \
  | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes?ref=development" \
  | kubectl apply -f -


kubectl port-forward svc/release-name-argocd-server 8080:8080 -n argocd

# # sudo chmod a+r /etc/rancher/rke2/rke2.yaml