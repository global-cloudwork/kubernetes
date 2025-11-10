#!/bin/bash

echo "===== CLUSTER DEBUG SUMMARY ====="

# 1. Namespaces
echo "=== Namespaces ==="
kubectl get ns
echo

# 2. Node status
echo "=== Nodes ==="
kubectl get nodes -o wide | awk '$2!="Ready"{print "Node not ready:", $0}'
echo

# 3. Pods with issues
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
echo

# 4. Services without endpoints
echo "=== Services without Endpoints ==="
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers); do
  for svc in $(kubectl get svc -n $ns -o custom-columns=NAME:.metadata.name --no-headers); do
    EPS=$(kubectl get endpoints $svc -n $ns -o jsonpath='{.subsets}' 2>/dev/null)
    [ -z "$EPS" ] && echo "$ns/$svc has no endpoints"
  done
done
echo

# 5. Recent critical events
echo "=== Recent Critical Events ==="
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers); do
  kubectl get events -n $ns --field-selector=type=Warning \
    --sort-by='.lastTimestamp' -o custom-columns=TIME:.lastTimestamp,OBJ:.involvedObject.name,REASON:.reason,MESSAGE:.message \
    | tail -5
done

echo "===== SUMMARY COMPLETE ====="
