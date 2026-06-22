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
# Gateway API & Traefik
# -----------------------------------------------------------------------------

section "Gateway API — GatewayClasses"

echo "=== GatewayClasses ==="
kubectl get gatewayclass -o wide 2>/dev/null || warn "No GatewayClass resources found"

echo ""
echo "=== GatewayClass Conditions ==="
kubectl get gatewayclass -o json 2>/dev/null | \
  jq -r '.items[] | "[\(.metadata.name)] controller: \(.spec.controllerName) | accepted: \(.status.conditions[]? | select(.type=="Accepted") | .status)"' \
  || warn "Could not parse GatewayClass conditions (jq may not be installed)"

section "Gateway API — Gateways"

echo "=== Gateways ==="
kubectl get gateway -A -o wide 2>/dev/null || warn "No Gateway resources found"

echo ""
echo "=== Gateway Conditions ==="
kubectl get gateway -A -o json 2>/dev/null | \
  jq -r '.items[] | "[\(.metadata.namespace)/\(.metadata.name)] programmed: \(.status.conditions[]? | select(.type=="Programmed") | .status) | ready: \(.status.conditions[]? | select(.type=="Ready") | .status)"' \
  || warn "Could not parse Gateway conditions (jq may not be installed)"

echo ""
echo "=== Gateway Addresses ==="
kubectl get gateway -A -o json 2>/dev/null | \
  jq -r '.items[] | "[\(.metadata.namespace)/\(.metadata.name)] addresses: \([.status.addresses[]?.value] | join(", "))"' \
  || warn "Could not parse Gateway addresses"

section "Gateway API — HTTPRoutes"

echo "=== HTTPRoutes ==="
kubectl get httproute -A -o wide 2>/dev/null || warn "No HTTPRoute resources found"

echo ""
echo "=== HTTPRoute Details (hostnames & backends) ==="
kubectl get httproute -A -o json 2>/dev/null | \
  jq -r '.items[] | "[\(.metadata.namespace)/\(.metadata.name)] hostnames: \(.spec.hostnames // [] | join(", ")) | parent: \(.spec.parentRefs[]? | "\(.namespace // "same ns")/\(.name)")"' \
  || warn "Could not parse HTTPRoute details"

section "Traefik"

echo "=== Traefik Pods ==="
kubectl get pods -A -l 'app.kubernetes.io/name=traefik' -o wide 2>/dev/null \
  || kubectl get pods -A -l 'app=traefik' -o wide 2>/dev/null \
  || warn "No Traefik pods found"

echo ""
echo "=== Traefik Services ==="
kubectl get svc -A -l 'app.kubernetes.io/name=traefik' 2>/dev/null \
  || kubectl get svc -A -l 'app=traefik' 2>/dev/null \
  || warn "No Traefik services found"

echo ""
echo "=== Traefik Deployment ==="
kubectl get deployment -A -l 'app.kubernetes.io/name=traefik' -o wide 2>/dev/null \
  || kubectl get deployment -A -l 'app=traefik' -o wide 2>/dev/null \
  || warn "No Traefik deployment found"

section "Local Network Reachability"

echo "=== Probing HTTPRoute hostnames ==="

if ! command -v curl >/dev/null 2>&1; then
  warn "curl not installed — skipping reachability checks"
else
  HOSTNAMES=$(kubectl get httproute -A -o json 2>/dev/null | \
    jq -r '.items[].spec.hostnames[]?' 2>/dev/null || true)

  if [[ -z "$HOSTNAMES" ]]; then
    warn "No hostnames found in HTTPRoutes"
  else
    while IFS= read -r hostname; do
      [[ -z "$hostname" ]] && continue

      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 3 "http://$hostname" 2>/dev/null || echo "000")
      HTTPS_CODE=$(curl -ks -o /dev/null -w "%{http_code}" \
        --connect-timeout 3 "https://$hostname" 2>/dev/null || echo "000")

      if [[ "$HTTP_CODE" =~ ^(200|301|302|401|403|404)$ ]] || \
         [[ "$HTTPS_CODE" =~ ^(200|301|302|401|403|404)$ ]]; then
        echo -e "${GREEN}✓${NC} $hostname — HTTP: $HTTP_CODE  HTTPS: $HTTPS_CODE"
      else
        echo -e "${RED}✗${NC} $hostname — HTTP: $HTTP_CODE  HTTPS: $HTTPS_CODE (unreachable)"
      fi
    done <<< "$HOSTNAMES"
  fi
fi

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

section "Argo CD Applications"

echo "=== Applications ==="
kubectl get applications -n argocd 2>/dev/null || warn "No ArgoCD Applications found"

echo ""
echo "=== ApplicationSets ==="
kubectl get applicationsets -n argocd 2>/dev/null || warn "No ArgoCD ApplicationSets found"

echo ""
echo "=== Sync & Health Status ==="
kubectl get applications -n argocd -o json 2>/dev/null | \
  jq -r '.items[] | "[\(.metadata.name)] sync: \(.status.sync.status) | health: \(.status.health.status)"' \
  || warn "Could not parse ArgoCD application status"

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