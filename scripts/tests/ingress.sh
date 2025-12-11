kubectl describe gateway -A
kubectl describe httproute -A
kubectl describe clusterissuer -A

ubuntu@development:~$ kubectl get secrets -A | grep wildcard-certificate

kubectl get gateway -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.parents[*].conditions[?(@.type=="Programmed")].status}{"\n"}{end}'
kubectl get clusterissuer -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

kubectl run dns-test --image=busybox:latest --restart=Never --rm -it -- sh

kubectl get pod cert-manager-794db7f658-cfhbj -n cert-manager -o wide

kubectl run connectivity-test -it --rm --image=curlimages/curl --restart=Never \
--overrides='{"spec": {"nodeSelector": {"kubernetes.io/hostname": "gateway"}}}' \
-- /bin/sh

curl -k -v https://10.43.0.1:443

ip route get 10.43.0.1

curl -k https://$NODE_IP:$PORT/healthz