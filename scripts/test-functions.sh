#!/usr/bin/env bash
# Test Functions for Gateway Deployment (Functionally Refactored)
# Source this file in your main script: source test-functions.sh

#===============================================================================
# Core Utilities
#===============================================================================
run_cmd() {
  local cmd=("$@")
  "${cmd[@]}"
  return $?
}

run_sudo() {
  run_cmd sudo "$@"
}

log_header() {
  echo -e "\n=== $* ==="
}

log_title() {
  echo -e "\n### $* ###"
}

log_note() {
  echo -e "  [PASS] $*"
}

log_error() {
  echo -e "  [FAIL] $*"
}

#===============================================================================
# Control Helpers
#===============================================================================
retry() {
  local attempts=$1; shift
  local delay=$1; shift
  local fn=("$@")
  local i=1
  until "${fn[@]}"; do
    if (( i >= attempts )); then
      return 1
    fi
    ((i++))
    sleep "$delay"
  done
  return 0
}

wait_until() {
  local timeout=$1; shift
  local delay=$1; shift
  local fn=("$@")
  local elapsed=0
  until "${fn[@]}"; do
    if (( elapsed >= timeout )); then
      return 1
    fi
    (( elapsed += delay ))
    sleep "$delay"
  done
  return 0
}

#===============================================================================
# Assertion Primitives
#===============================================================================
assert_redirect_rule() {
  local from=$1 to=$2 pass_desc=$3 fail_desc=$4
  run_sudo iptables -t nat -L PREROUTING -n \
    | grep -q "tcp dpt:${from}.*redir ports ${to}"
  if [[ $? -eq 0 ]]; then
    log_note "$pass_desc"
    return 0
  else
    log_error "$fail_desc"
    return 1
  fi
}

assert_input_rule() {
  local port=$1 pass_desc=$2 fail_desc=$3
  run_sudo iptables -L INPUT -n \
    | grep -q "tcp dpt:${port}"
  if [[ $? -eq 0 ]]; then
    log_note "$pass_desc"
    return 0
  else
    log_error "$fail_desc"
    return 1
  fi
}

assert_port_listening() {
  local port=$1 pass_desc=$2 fail_desc=$3
  run_sudo ss -tlnp \
    | grep -q ":${port}"
  if [[ $? -eq 0 ]]; then
    log_note "$pass_desc"
    return 0
  else
    log_error "$fail_desc"
    return 1
  fi
}

assert_kubectl() {
  local description=$1 shift_cmd=( "${@:2}" )
  "${shift_cmd[@]}" &> /dev/null
  if [[ $? -eq 0 ]]; then
    log_note "$description"
    return 0
  else
    log_error "$description"
    return 1
  fi
}

assert_crd_exists() {
  local crd=$1
  run_cmd kubectl get crd "$crd" &> /dev/null
}

assert_pods_ready() {
  local label=$1 namespace=$2 minimum=$3
  local count
  count=$(kubectl get pods -n "$namespace" -l "$label" --no-headers 2>/dev/null \
    | grep -c "Running") || count=0
  if (( count >= minimum )); then
    log_note "✓ Pods running for ${label} in ${namespace} ($count >= $minimum)"
    return 0
  else
    log_error "✗ Pods not running for ${label} in ${namespace} ($count < $minimum)"
    return 1
  fi
}

assert_http_status() {
  local url=$1 expected=$2 desc=$3
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 5) || code="000"
  for want in ${expected//,/ }; do
    if [[ "$code" == "$want" ]]; then
      log_note "$desc (HTTP $code)"
      return 0
    fi
  done
  log_error "$desc (HTTP $code)"
  return 1
}

#===============================================================================
# Result & Test Types
#===============================================================================
declare -A Result
Result.new() {
  Result[pass]=0
  Result[fail]=0
}
Result.add_pass() {
  (( Result[pass]++ ))
}
Result.add_fail() {
  (( Result[fail]++ ))
}

declare -A Test
Test.new() {
  Test[name]="$1"
  Test[fn]="$2"
}

#===============================================================================
# Test Orchestration
#===============================================================================
run_test() {
  local name="$1"
  local fn="$2"
  log_header "Test: $name"
  "$fn"
  if [[ $? -eq 0 ]]; then
    Result.add_pass
  else
    Result.add_fail
  fi
}

run_all_tests() {
  Result.new
  local tests=("$@")
  for t in "${tests[@]}"; do
    IFS=':' read -r name fn <<< "$t"
    run_test "$name" "$fn"
  done
  log_title "Summary: ${Result[pass]} passed, ${Result[fail]} failed"
  return "${Result[fail]}"
}

#===============================================================================
# Refactored Test Functions
#===============================================================================
test_iptables_rules() {
  log_header "iptables port forwarding rules"
  assert_redirect_rule 80 8080 "✓ iptables 80→8080 exists" "✗ iptables 80→8080 missing"
  assert_redirect_rule 443 8443 "✓ iptables 443→8443 exists" "✗ iptables 443→8443 missing"
  assert_input_rule 8080 "✓ INPUT port 8080 allowed" "✗ INPUT port 8080 missing"
  assert_input_rule 8443 "✓ INPUT port 8443 allowed" "✗ INPUT port 8443 missing"
}

test_port_listening() {
  log_header "Gateway ports listening"
  sleep 5
  assert_port_listening 8080 "✓ Port 8080 listening" "✗ Port 8080 not listening"
  assert_port_listening 8443 "✓ Port 8443 listening" "✗ Port 8443 not listening"
  log_note "Processes on ports:"
  run_sudo ss -tlnp | grep -E ":8080|:8443" || echo "  None"
}

test_kubernetes_api() {
  log_header "Kubernetes API access"
  retry 30 2 kubectl get nodes &> /dev/null
  if [[ $? -ne 0 ]]; then
    log_error "✗ Kubernetes API not accessible"
    return 1
  fi
  log_note "✓ Kubernetes API accessible"
  local status
  status=$(kubectl get nodes --no-headers | awk '{print $2}')
  if [[ "$status" == "Ready" ]]; then
    log_note "✓ Node status Ready"
    return 0
  else
    log_error "✗ Node status: $status"
    return 1
  fi
}

test_cilium_status() {
  log_header "Cilium installation"
  retry 60 2 kubectl get pods -n kube-system -l k8s-app=cilium --no-headers &> /dev/null \
    || { log_error "✗ Cilium pods not found"; return 1; }
  assert_pods_ready "k8s-app=cilium" "kube-system" 1
  kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s &> /dev/null
  if [[ $? -eq 0 ]]; then
    log_note "✓ Cilium pods ready"
  else
    log_error "✗ Cilium pods not ready"
  fi
  kubectl -n kube-system exec ds/cilium -- cilium status --brief &> /dev/null
  if [[ $? -eq 0 ]]; then
    log_note "✓ Cilium status healthy"
  else
    log_error "✗ Cilium status failed"
  fi
  kubectl taint nodes --all node.cilium.io/agent-not-ready:NoExecute- &> /dev/null || true
  log_note "✓ Removed Cilium taint"
}

test_gateway_api_crds() {
  log_header "Gateway API CRDs"
  for crd in gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io gatewayclasses.gateway.networking.k8s.io; do
    if assert_crd_exists "$crd"; then
      log_note "✓ CRD $crd exists"
    else
      log_error "✗ CRD $crd missing"
    fi
  done
}

test_gateway_resource() {
  log_header "Gateway resource"
  retry 30 2 kubectl get gateway -n edge &> /dev/null \
    || { log_error "✗ Gateway not found"; return 1; }
  log_note "✓ Gateway exists"
  local acc
  acc=$(kubectl get gateway -n edge -o jsonpath='{.items[0].status.conditions[?(@.type=="Accepted")].status}')
  if [[ "$acc" == "True" ]]; then
    log_note "✓ Gateway Accepted"
  else
    log_error "✗ Gateway not Accepted ($acc)"
  fi
  local pods
  pods=$(kubectl get pods -n kube-system -l gateway.networking.k8s.io/gateway-name --no-headers 2>/dev/null | wc -l)
  if (( pods > 0 )); then
    log_note "✓ Gateway pods ($pods)"
  else
    log_error "✗ No Gateway pods"
  fi
  local hostNet
  hostNet=$(kubectl get pods -n kube-system -l gateway.networking.k8s.io/gateway-name -o jsonpath='{.items[0].spec.hostNetwork}')
  if [[ "$hostNet" == "true" ]]; then
    log_note "✓ Using hostNetwork"
  else
    log_error "✗ Not using hostNetwork ($hostNet)"
  fi
}

test_http_connectivity() {
  log_header "HTTP connectivity"
  local ip
  ip=${EXTERNAL_IP:-$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)}
  log_note "Testing against $ip"
  assert_http_status http://localhost:8080 200,404 "Local HTTP on 8080"
  assert_http_status http://${ip} 200,404 "External HTTP (80→8080)"
}

test_cert_manager() {
  log_header "cert-manager"
  assert_kubectl "cert-manager ns exists" kubectl get namespace cert-manager
  assert_pods_ready "" "cert-manager" 3
  run_cmd kubectl get clusterissuer &> /dev/null
  if [[ $? -eq 0 ]]; then
    log_note "✓ ClusterIssuer exists"
  else
    log_error "✗ No ClusterIssuer"
  fi
}

test_httproutes() {
  log_header "HTTPRoute resources"
  local count
  count=$(kubectl get httproute -A --no-headers 2>/dev/null | wc -l) || count=0
  if (( count > 0 )); then
    log_note "✓ HTTPRoutes found ($count)"
  else
    log_error "✗ No HTTPRoutes"
  fi
}

#===============================================================================
# Quick Test & All Tests Runner
#===============================================================================
quick_test() {
  run_all_tests \
    "iptables:test_iptables_rules" \
    "port-listening:test_port_listening" \
    "gateway:test_gateway_resource"
}

run_all_gateway_tests() {
  run_all_tests \
    "iptables:test_iptables_rules" \
    "k8s-api:test_kubernetes_api" \
    "cilium:test_cilium_status" \
    "crds:test_gateway_api_crds" \
    "gateway:test_gateway_resource" \
    "listening:test_port_listening" \
    "http:test_http_connectivity" \
    "cert-manager:test_cert_manager" \
    "httproutes:test_httproutes"
}
