kubectl apply -k https://github.com/global-cloudwork/kubernetes/development

kubectl kustomize "github.com/global-cloudwork/kubernetes//kustomize?ref=development" --enable-helm | kubectl apply -f -

kubectl kustomize --enable-helm \
  "github.com/global-cloudwork/kubernetes?ref=development" \
  | kubectl apply --dry-run=client -f -