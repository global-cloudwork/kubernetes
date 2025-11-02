#!/bin/bash

#Functions return a string run as a command in other functions
unfinished_pods() {
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace} {.metadata.name} {.status.phase} {.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null \
        | awk '$3 == "Running" && $4 != "True" || $3 == "Pending" || $3 == "Failed" {print $1"/"$2}'
}
unfinished_endpoints() {
    kubectl get endpoints --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace} { .metadata.name} { .subsets[*].addresses[*].ip}{"\n"}{end}' 2>/dev/null \
        | awk '$3 == "" {print $1"/"$2}'
}
unfinished_crds() {
    kubectl get crds -o jsonpath='{range .items[*]}{.metadata.name} { .status.conditions[?(@.type=="Established")].status}{"\n"}{end}' 2>/dev/null \
        | awk '$2 != "True" {print $1}'
}

# Uses dynamic function names based on type to wait for resources to be ready
wait_for() {
    local TYPE="$1"
    local SECONDS_TO_WAIT="${SECONDS_TO_WAIT:-10}"
    local MAX_ITERATIONS="${MAX_ITERATIONS:-20}"

    local FUNC_NAME="unfinished_$TYPE"

    # Check if the function exists
    if ! declare -f "$FUNC_NAME" >/dev/null; then
        section "ERROR: Type '$TYPE' not supported"
        return 1
    fi

    section "Function - Wait for all $TYPE"

    local ITERATIONS=1
    local STRING

    while true; do
        STRING=$($FUNC_NAME)

        # Check for "ERROR" in output
        if echo "$STRING" | grep -iq "error"; then
            error "Error detected while checking $TYPE"
            while IFS= read -r line; do
                header "$line"
            done <<< "$STRING"
            return 1
        fi

        # Check if all resources are ready
        if [[ -z "$STRING" ]]; then
            header "Iteration $ITERATIONS: All $TYPE are ready"
            break
        fi

        # Print current status
        header "Itteration $ITERATIONS: The following $TYPE are not yet ready:"
        while IFS= read -r line; do
            echo "$line"
        done <<< "$STRING"

        # Increment retry count
        ((ITERATIONS++))
        if ((ITERATIONS > MAX_ITERATIONS)); then
            error "Reached maximum retries. Exiting..."
            return 2
        fi

        sleep "$SECONDS_TO_WAIT"
    done
}