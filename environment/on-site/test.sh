echo "=== Cluster Info ==="
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces

echo "=== Argo CD Pods ==="
kubectl get pods -n argocd
kubectl get pods -n argocd -o wide

echo "=== Services ==="
kubectl get svc -n argocd
kubectl describe svc argocd-server -n argocd
kubectl get svc argocd-server -n argocd -o wide

echo "=== Endpoints ==="
kubectl get endpoints -n argocd argocd-server
kubectl get endpointslice -n argocd

echo "=== Host Port Checks ==="
ss -lntp | grep 30080 || echo "30080 not listening on host"
ss -lntp | grep 30443 || echo "30443 not listening on host"

echo "=== Docker Kind Node ==="
docker ps
docker inspect kind-control-plane | grep -A 30 PortBindings

echo "=== External Access Tests ==="
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:30080 || echo "HTTP failed"
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost:30443 || echo "HTTPS failed"

echo "=== Node IP Test Hint ==="
kubectl get nodes -o wide

echo "=== DONE ==="