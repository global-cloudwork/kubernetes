kubectl get gateway -A
kubectl get httproute -A
kubectl get certificate -A
kubectl get secret -n gateway dns-key
kubectl describe certificate -n gateway wildcard-certificate-2
kubectl logs -n cert-manager deploy/cert-manager
kubectl logs -n cert-manager deploy/cert-manager-webhook
kubectl logs -n cert-manager deploy/cert-manager-cainjector
kubectl get pods -n cert-manager
kubectl get pods -n gateway
kubectl describe pod -n gateway $(kubectl get pods -n gateway -o jsonpath="{.items[0].metadata.name}")
kubectl get events -n gateway
kubectl get pods -A
kubectl describe pod -n cert-manager $(kubectl get pods -n cert-manager -o jsonpath="{.items[0].metadata.name}")
kubectl get events -n cert-manager
kubectl describe pod -n cert-manager $(kubectl get pods -n cert-manager -o jsonpath="{.items[1].metadata.name}")


