kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/keycloak/keycloak/blob/534a37f3562851ad3cc6b33ad755d7378ddb4e3c/operator/src/main/kubernetes/kubernetes.yml

# Apply new argocd crds
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds
