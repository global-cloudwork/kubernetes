#!/usr/bin/env bash

# Kubernetes Cluster Health & ArgoCD Validation Script
# Usage:
#   chmod +x k8s-cluster-check.sh
#   ./k8s-cluster-check.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

section() {
  echo -e "\n${GREEN}==== $1 ====${NC}"
}

warn() {
  echo -e "${YELLOW}[WARN] $1${NC}"
}

error() {
  echo -e "${RED}[ERROR] $1${NC}"
}

run_cmd() {
  local cmd="$1"
  echo -e "\n$ $cmd"
  bash -c "$cmd" || warn "Command failed: $cmd"
}

# -----------------------------------------------------------------------------
# Dependency Checks
# -----------------------------------------------------------------------------

for bin in kubectl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    error "$bin is not installed"
    exit 1
  fi
done

# -----------------------------------------------------------------------------
# Basic Cluster Information
# -----------------------------------------------------------------------------

section "Cluster Info"

run_cmd "kubectl version --short || kubectl version"
run_cmd "kubectl config current-context"

echo "=== Cluster Info ==="
run_cmd "kubectl cluster-info"
run_cmd "kubectl get nodes -o wide"
run_cmd "kubectl get namespaces"

# -----------------------------------------------------------------------------
# Nodes & Resource Usage
# -----------------------------------------------------------------------------

section "Node Status"

run_cmd "kubectl get nodes -o wide"

if kubectl top nodes >/dev/null 2>&1; then
  run_cmd "kubectl top nodes"
else
  warn "Metrics server not installed or metrics unavailable"
fi

# -----------------------------------------------------------------------------
# Pod Checks
# -----------------------------------------------------------------------------

section "All Pods"

run_cmd "kubectl get pods -A -o wide"

section "Non-Running Pods"

NON_RUNNING=$(kubectl get pods -A \
  --field-selector=status.phase!=Running,status.phase!=Succeeded \
  --no-headers || true)

if [[ -n "$NON_RUNNING" ]]; then
  echo "$NON_RUNNING"
else
  echo "All pods are healthy"
fi

section "Restarting Containers"

kubectl get pods -A --no-headers | awk '$5 > 0 {print}' || true

section "CrashLoopBackOff Checks"

kubectl get pods -A | grep CrashLoopBackOff || echo "No CrashLoopBackOff pods"

section "Pending Pods"

kubectl get pods -A | grep Pending || echo "No Pending pods"

# -----------------------------------------------------------------------------
# Workloads
# -----------------------------------------------------------------------------

section "Deployments"

run_cmd "kubectl get deployments -A"

section "StatefulSets"

run_cmd "kubectl get statefulsets -A"

section "DaemonSets"

run_cmd "kubectl get daemonsets -A"

# -----------------------------------------------------------------------------
# Networking & Services
# -----------------------------------------------------------------------------

section "Services"

run_cmd "kubectl get svc -A"

section "Ingress"

kubectl get ingress -A 2>/dev/null || warn "No ingress resources found"

section "Network Policies"

kubectl get networkpolicy -A 2>/dev/null || warn "No network policies found"

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

section "Persistent Storage"

run_cmd "kubectl get pvc -A"
run_cmd "kubectl get pv"
run_cmd "kubectl get storageclass"

# -----------------------------------------------------------------------------
# Events
# -----------------------------------------------------------------------------

section "Recent Events"

run_cmd "kubectl get events -A --sort-by='.lastTimestamp' | tail -50"

section "Failure Events"

kubectl get events -A | grep -Ei 'fail|error|backoff|evict|unhealthy' \
  || echo "No major failed events found"

# -----------------------------------------------------------------------------
# ArgoCD Checks
# -----------------------------------------------------------------------------

section "Argo CD Pods"

echo "=== Argo CD Pods ==="
run_cmd "kubectl get pods -n argocd"
run_cmd "kubectl get pods -n argocd -o wide"

section "Argo CD Services"

echo "=== Services ==="
run_cmd "kubectl get svc -n argocd"
run_cmd "kubectl describe svc argocd-server -n argocd"
run_cmd "kubectl get svc argocd-server -n argocd -o wide"

section "Argo CD Endpoints"

echo "=== Endpoints ==="
run_cmd "kubectl get endpoints -n argocd argocd-server"
run_cmd "kubectl get endpointslice -n argocd"

# -----------------------------------------------------------------------------
# Host Port Checks
# -----------------------------------------------------------------------------

section "Host Port Checks"

echo "=== Host Port Checks ==="

if command -v ss >/dev/null 2>&1; then
  ss -lntp | grep 30080 || echo "30080 not listening on host"
  ss -lntp | grep 30443 || echo "30443 not listening on host"
else
  warn "'ss' command not available"
fi

# -----------------------------------------------------------------------------
# Kind / Docker Checks
# -----------------------------------------------------------------------------

section "Docker Kind Node"

echo "=== Docker Kind Node ==="

if command -v docker >/dev/null 2>&1; then
  run_cmd "docker ps"

  if docker ps --format '{{.Names}}' | grep -q '^kind-control-plane$'; then
    run_cmd "docker inspect kind-control-plane | grep -A 30 PortBindings"
  else
    warn "kind-control-plane container not found"
  fi
else
  warn "Docker not installed"
fi

# -----------------------------------------------------------------------------
# External Access Tests
# -----------------------------------------------------------------------------

section "External Access Tests"

echo "=== External Access Tests ==="

if command -v curl >/dev/null 2>&1; then
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:30080 \
    || echo "HTTP failed"

  curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost:30443 \
    || echo "HTTPS failed"
else
  warn "curl not installed"
fi

# -----------------------------------------------------------------------------
# Additional Cluster Details
# -----------------------------------------------------------------------------

section "API Resources"

run_cmd "kubectl api-resources"

section "Component Status"

kubectl get componentstatuses 2>/dev/null \
  || warn "componentstatuses API may be deprecated"

section "Kubernetes Version"

run_cmd "kubectl version -o yaml"

section "Helm Releases"

if command -v helm >/dev/null 2>&1; then
  run_cmd "helm list -A"
else
  warn "Helm not installed"
fi

# -----------------------------------------------------------------------------
# Node IP Hint
# -----------------------------------------------------------------------------

section "Node IP Test Hint"

echo "=== Node IP Test Hint ==="
run_cmd "kubectl get nodes -o wide"

# -----------------------------------------------------------------------------
# Finished
# -----------------------------------------------------------------------------

section "DONE"



echo -e "${GREEN}Kubernetes cluster check finished successfully.${NC}"

