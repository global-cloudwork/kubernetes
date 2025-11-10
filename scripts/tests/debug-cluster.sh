#!/bin/bash
# curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/debug-cluster.sh | bash
# debug-cluster: Collects cluster info and checks for errors in resources

echo "===== DEBUGGING KUBERNETES CLUSTER ====="

# 1. List all namespaces
echo "===== NAMESPACES ====="
kubectl get namespaces
echo

# 2. Node details
echo "===== NODES (wide) ====="
kubectl get nodes -o wide
echo

# 3. Pods: check logs for errors
echo "===== POD LOGS ====="
for pod in $(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
  NAMESPACE=$(echo $pod | cut -d',' -f1)
  NAME=$(echo $pod | cut -d',' -f2)
  echo "--- Checking logs for $NAMESPACE/$NAME ---"
  kubectl logs -n $NAMESPACE $NAME --tail=500 2>/dev/null | grep -i error
  echo
done

# 4. Services: describe each service
echo "===== SERVICES ====="
for svc in $(kubectl get svc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
  NAMESPACE=$(echo $svc | cut -d',' -f1)
  NAME=$(echo $svc | cut -d',' -f2)
  echo "--- Describing service $NAMESPACE/$NAME ---"
  kubectl describe svc -n $NAMESPACE $NAME
  echo
done

# 5. Endpoints: describe each endpoint
echo "===== ENDPOINTS ====="
for ep in $(kubectl get endpoints -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/  */,/g'); do
  NAMESPACE=$(echo $ep | cut -d',' -f1)
  NAME=$(echo $ep | cut -d',' -f2)
  echo "--- Describing endpoint $NAMESPACE/$NAME ---"
  kubectl describe endpoints -n $NAMESPACE $NAME
  echo
done

# 6. Additional pod checks (events)
echo "===== POD EVENTS ====="
for ns in $(kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers); do
  echo "--- Events in namespace $ns ---"
  kubectl get events -n $ns --sort-by='.lastTimestamp'
  echo
done

echo "===== DEBUGGING COMPLETE ====="
