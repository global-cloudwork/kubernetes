#!/bin/bash
# wait-for-k8s.sh
# Waits for Kubernetes components to be ready before proceeding
# Can be used prior to `kustomize apply` or other cluster operations

set -e

NAMESPACE_LIST=(
    "kube-system"
    "cert-manager"
    "default"
)
CHECK_INTERVAL=5

echo "Waiting for Kubernetes components to be ready..."

wait_for_pods() {
    local namespace="$1"
    echo "Checking pods in namespace: $namespace"
    
    while true; do
        NOT_READY=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null \
                    | awk '$2 != $3 {print $0}')
        if [[ -z "$NOT_READY" ]]; then
            echo "All pods in $namespace are ready"
            break
        else
            echo "Waiting for pods in $namespace to be ready..."
            sleep $CHECK_INTERVAL
        fi
    done
}

wait_for_crds() {
    echo "Checking CRDs..."
    while true; do
        # Ensure all CRDs are established
        NOT_ESTABLISHED=$(kubectl get crds -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
                          2>/dev/null | while read crd; do
                              STATUS=$(kubectl get crd "$crd" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}')
                              [[ "$STATUS" != "True" ]] && echo "$crd"
                          done)
        if [[ -z "$NOT_ESTABLISHED" ]]; then
            echo "All CRDs are established"
            break
        else
            echo "Waiting for CRDs to be established..."
            sleep $CHECK_INTERVAL
        fi
    done
}

wait_for_services_endpoints() {
    echo "Checking service endpoints..."
    while true; do
        NOT_READY_ENDPOINTS=$(kubectl get endpoints --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.subsets[*].addresses[*].ip}{"\n"}{end}' \
                            2>/dev/null | awk '$3=="" {print $1"/"$2}')
        if [[ -z "$NOT_READY_ENDPOINTS" ]]; then
            echo "All service endpoints have ready addresses"
            break
        else
            echo "Waiting for endpoints to be ready: $NOT_READY_ENDPOINTS"
            sleep $CHECK_INTERVAL
        fi
    done
}

# Loop through important namespaces
for ns in "${NAMESPACE_LIST[@]}"; do
    wait_for_pods "$ns"
done

# Ensure CRDs are established
wait_for_crds

# Ensure service endpoints exist
wait_for_services_endpoints

echo "All key Kubernetes components are ready. Safe to continue."
