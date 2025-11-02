- Node health\
  • `kubectl get nodes -o wide`\
  • `kubectl describe node <node-name>`

- Pod status across all namespaces\
  • `kubectl get pods --all-namespaces`\
  • Filter by failures:\
  `kubectl get pods --all-namespaces --field-selector=status.phase=Failed`

- Recent cluster events\
  • `kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp`

- Drill into failing workloads\
  • `kubectl describe pod <pod-name> -n <namespace>`\
  • `kubectl logs <pod-name> -n <namespace>`\
  • For multi-container pods: `kubectl logs <pod-name> -c <container-name> -n <namespace>`

- Control-plane/component status\
  • `kubectl get componentstatuses`\
  • (If using kubeadm) `kubectl get cs`

- Resource metrics (if metrics-server installed)\
  • `kubectl top nodes`\
  • `kubectl top pods --all-namespaces`

- Full diagnostics dump\
  • `kubectl cluster-info dump --output-directory=./cluster-dump`

`kubectl cluster-info dump > cluster_dump.json`
`kubectl cluster-info dump | grep -i error`