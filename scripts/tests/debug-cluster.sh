#!/bin/bash
# Run: curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/debug-cluster.sh | bash

echo "===== CLUSTER DEBUG SUMMARY ====="

# Namespaces
echo "=== Namespaces ==="
kubectl get ns

# Node status
echo "=== Node Status ==="
kubectl get nodes -o wide | awk '$2!="Ready"{print "Node not ready:", $0}'

# Describe the single node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "=== Describe Node: $NODE_NAME ==="
kubectl describe node $NODE_NAME

# Pods with issues
echo "=== Pods with Issues ==="
kubectl get pods -A --field-selector=status.phase!=Running \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase

echo "--- Pods with errors in logs (last 100 lines) ---"
for pod in $(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
  NAMESPACE=$(echo $pod | cut -d',' -f1)
  NAME=$(echo $pod | cut -d',' -f2)
  ERRORS=$(kubectl logs -n $NAMESPACE $NAME --tail=100 2>/dev/null | grep -i error)
  [ -n "$ERRORS" ] && echo "$NAMESPACE/$NAME: $(echo "$ERRORS" | head -1) ..."
done

# Services without endpoints
echo "=== Services without Endpoints ==="
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers); do
  for svc in $(kubectl get svc -n $ns -o custom-columns=NAME:.metadata.name --no-headers); do
    EPS=$(kubectl get endpoints $svc -n $ns -o jsonpath='{.subsets}' 2>/dev/null)
    [ -z "$EPS" ] && echo "$ns/$svc has no endpoints"
  done
done

# Recent Warning Events only (issues)
echo "=== Recent Warning Events (Issues Only) ==="
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers); do
  kubectl get events -n $ns --field-selector=type=Warning \
    --sort-by='.lastTimestamp' -o custom-columns=TIME:.lastTimestamp,OBJ:.involvedObject.name,REASON:.reason,MESSAGE:.message \
    | tail -10
done

echo "===== SUMMARY COMPLETE ====="
