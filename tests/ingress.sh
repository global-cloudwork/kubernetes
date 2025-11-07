kubectl describe gateway -A
kubectl describe httproute -A
kubectl describe clusterissuer -A

ubuntu@development:~$ kubectl get secrets -A | grep wildcard-certificate



kubectl get gateway -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.parents[*].conditions[?(@.type=="Programmed")].status}{"\n"}{end}'
kubectl get clusterissuer -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

