#!/bin/bash
# Run: curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/debug-cluster.sh | bash

echo "===== CLUSTER DEBUG SUMMARY ====="

# Namespaces
NS=$(kubectl get ns)
[ -n "$NS" ] && echo "=== Namespaces ===" && echo "$NS"

# Node status
NODES=$(kubectl get nodes -o wide | awk '$2!="Ready"{print "Node not ready:", $0}')
[ -n "$NODES" ] && echo "=== Node Status ===" && echo "$NODES"

# Describe the single node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
if [ -n "$NODE_NAME" ]; then
  echo "=== Describe Node: $NODE_NAME ==="
  kubectl describe node "$NODE_NAME"
fi

# Pods with issues
PODS_ISSUES=$(kubectl get pods -A --field-selector=status.phase!=Running -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase)
if [ -n "$PODS_ISSUES" ]; then
  echo "=== Pods with Issues ==="
  echo "$PODS_ISSUES"
fi

# Pods with errors in logs
LOG_ERRORS=""
for pod in $(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
  NAMESPACE=$(echo $pod | cut -d',' -f1)
  NAME=$(echo $pod | cut -d',' -f2)
  ERRORS=$(kubectl logs -n $NAMESPACE $NAME --tail=100 2>/dev/null | grep -i error)
  [ -n "$ERRORS" ] && LOG_ERRORS+="$NAMESPACE/$NAME: $(echo "$ERRORS" | head -1) ..."$'\n'
done
[ -n "$LOG_ERRORS" ] && echo "--- Pods with errors in logs (last 100 lines) ---" && echo "$LOG_ERRORS"

# Services without endpoints
SVC_ISSUES=""
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers); do
  for svc in $(kubectl get svc -n $ns -o custom-columns=NAME:.metadata.name --no-headers); do
    EPS=$(kubectl get endpoints $svc -n $ns -o jsonpath='{.subsets}' 2>/dev/null)
    [ -z "$EPS" ] && SVC_ISSUES+="$ns/$svc has no endpoints"$'\n'
  done
done
[ -n "$SVC_ISSUES" ] && echo "=== Services without Endpoints ===" && echo "$SVC_ISSUES"

# Recent Warning Events only (issues)
EVENTS_ISSUES=""
for ns in $(kubectl get ns -o custom-columns=NAME:.metadata.name --no-headers); do
  EV=$(kubectl get events -n $ns --field-selector=type=Warning --sort-by='.lastTimestamp' -o custom-columns=TIME:.lastTimestamp,OBJ:.involvedObject.name,REASON:.reason,MESSAGE:.message | tail -10)
  [ -n "$EV" ] && EVENTS_ISSUES+="$EV"$'\n'
done
[ -n "$EVENTS_ISSUES" ] && echo "=== Recent Warning Events (Issues Only) ===" && echo "$EVENTS_ISSUES"

echo "===== SUMMARY COMPLETE ====="

kubectl get nodes -o wide

kubectl describe nodes
