kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" > /etc/profile.d/k3s.sh
chmod 644 /etc/rancher/k3s/k3s.yaml

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d



