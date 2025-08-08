kubectl patch configmap argocd-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'