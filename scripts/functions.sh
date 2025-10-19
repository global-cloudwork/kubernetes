#!/bin/bash
# wait-for-k8s.sh
# Waits for Kubernetes components to be ready before proceeding
# Can be used prior to `kustomize apply` or other cluster operations

set -e


# Print formatted section headers
BOLD="\e[1m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
RESET="\e[0m"

title()   { printf "\n${BOLD}${UNDERLINE}\e[38;5;231m%s${RESET}\n" "$1"; }
section() { printf "\n${BOLD}${UNDERLINE}\e[38;5;51m%s${RESET}\n" "$1"; }
header()  { printf "\n${ITALIC}\e[38;5;33m%s${RESET}\n\n" "$1"; }
error()   { printf "\n${BOLD}${ITALIC}${UNDERLINE}\e[38;5;106m%s${RESET}\n" "$1"; }
note()    { printf "\n${BOLD}${ITALIC}\e[38;5;82m%s${RESET}\n" "$1"; }

#Functions return a string run as a command in other functions
unfinished_pods() {
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace} { .metadata.name} { .status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null \
        | awk '$3 != "True" {print $1"/"$2}'
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
    local SECONDS_TO_WAIT="${SECONDS_TO_WAIT:-5}"
    local MAX_ITERATIONS="${MAX_ITERATIONS:-60}"

    # Construct the dynamic function name
    local FUNC_NAME="unfinished_$TYPE"

    # Check if the function exists
    if ! declare -f "$FUNC_NAME" >/dev/null; then
        echo "ERROR: type of $FUNC_NAME not supported"
        return 1
    fi

    local ITERATIONS=0
    local STRING

    while true; do
        # Call the dynamic function and store output
        STRING=$($FUNC_NAME)

        # Check for "ERROR" in output
        if echo "$STRING" | grep -iq "error"; then
            echo "ERROR DETECTED:"
            echo "$STRING"
            return 1
        fi

        # Check if output is empty
        if [[ -z "$STRING" ]]; then
            echo "ALL $TYPE READY"
            break
        fi

        # Print current status
        echo "NOT READY YET ($TYPE):"
        echo "$STRING"

        # Increment retry count and check max
        ((ITERATIONS++))
        if ((ITERATIONS >= MAX_ITERATIONS)); then
            echo "REACHED MAXIMUM RETRIES ($MAX_ITERATIONS) FOR $TYPE. EXITING..."
            return 2
        fi

        sleep "$SECONDS_TO_WAIT"
    done
}

wait_for endpoints
wait_for pods
wait_for crds