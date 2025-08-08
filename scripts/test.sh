# Step 1: Create the namespace
kubectl create namespace argocd

# Step 2: Install Argo CD (latest stable version)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 3: Wait for components to be ready (optional but recommended)
kubectl rollout status deployment argocd-server -n argocd

# Step 4: Safely patch the ConfigMap to enable Helm in kustomize
kubectl patch configmap argocd-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'