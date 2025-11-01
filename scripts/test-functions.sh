#!/usr/bin/env bash
# Test Functions for Gateway Deployment
# Source this file in your main script: source test-functions.sh

#===============================================================================
# Test Function Definitions
#===============================================================================

test_iptables_rules() {
    header "Testing iptables port forwarding rules"
    
    local pass=0
    local fail=0
    
    # Check HTTP redirect (80 -> 8080)
    if sudo iptables -t nat -L PREROUTING -n | grep -q "tcp dpt:80.*redir ports 8080"; then
        note "✓ iptables rule 80→8080 exists"
        ((pass++))
    else
        error "✗ iptables rule 80→8080 NOT FOUND"
        ((fail++))
    fi
    
    # Check HTTPS redirect (443 -> 8443)
    if sudo iptables -t nat -L PREROUTING -n | grep -q "tcp dpt:443.*redir ports 8443"; then
        note "✓ iptables rule 443→8443 exists"
        ((pass++))
    else
        error "✗ iptables rule 443→8443 NOT FOUND"
        ((fail++))
    fi
    
    # Check if ports are allowed in INPUT chain
    if sudo iptables -L INPUT -n | grep -q "tcp dpt:8080"; then
        note "✓ Port 8080 allowed in INPUT chain"
        ((pass++))
    else
        error "✗ Port 8080 not allowed in INPUT chain"
        ((fail++))
    fi
    
    if sudo iptables -L INPUT -n | grep -q "tcp dpt:8443"; then
        note "✓ Port 8443 allowed in INPUT chain"
        ((pass++))
    else
        error "✗ Port 8443 not allowed in INPUT chain"
        ((fail++))
    fi
    
    printf "\niptables Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_port_listening() {
    header "Testing if Gateway ports are listening"
    
    local pass=0
    local fail=0
    
    # Wait a bit for Gateway to be ready
    sleep 5
    
    # Check if 8080 is listening
    if sudo ss -tlnp | grep -q ":8080"; then
        note "✓ Port 8080 is listening"
        ((pass++))
    else
        error "✗ Port 8080 is NOT listening (Gateway may not be ready)"
        ((fail++))
    fi
    
    # Check if 8443 is listening
    if sudo ss -tlnp | grep -q ":8443"; then
        note "✓ Port 8443 is listening"
        ((pass++))
    else
        error "✗ Port 8443 is NOT listening (Gateway may not be ready)"
        ((fail++))
    fi
    
    # Show what's listening on these ports
    note "Processes listening on gateway ports:"
    sudo ss -tlnp | grep -E ":8080|:8443" || echo "  None yet"
    
    printf "\nPort Listening Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_kubernetes_api() {
    header "Testing Kubernetes API access"
    
    local pass=0
    local fail=0
    local retries=30
    
    # Wait for API to be ready
    for i in $(seq 1 $retries); do
        if kubectl get nodes &> /dev/null; then
            note "✓ Kubernetes API is accessible"
            ((pass++))
            break
        fi
        
        if [ $i -eq $retries ]; then
            error "✗ Kubernetes API is NOT accessible after ${retries} attempts"
            ((fail++))
            return $fail
        fi
        
        sleep 2
    done
    
    # Check node status
    local node_status=$(kubectl get nodes --no-headers | awk '{print $2}')
    if [[ "$node_status" == "Ready" ]]; then
        note "✓ Node status is Ready"
        ((pass++))
    else
        error "✗ Node status is: $node_status"
        ((fail++))
    fi
    
    printf "\nKubernetes API Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_cilium_status() {
    header "Testing Cilium installation and status"
    
    local pass=0
    local fail=0
    local retries=60
    
    # Wait for Cilium pods to exist
    for i in $(seq 1 $retries); do
        if kubectl get pods -n kube-system -l k8s-app=cilium --no-headers &> /dev/null; then
            break
        fi
        
        if [ $i -eq $retries ]; then
            error "✗ Cilium pods not found after ${retries} attempts"
            ((fail++))
            return $fail
        fi
        
        sleep 2
    done
    
    # Check if Cilium pods are running
    local cilium_ready=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "$cilium_ready" -gt 0 ]]; then
        note "✓ Cilium pods are running ($cilium_ready pods)"
        ((pass++))
    else
        error "✗ Cilium pods are NOT running"
        ((fail++))
        return $fail
    fi
    
    # Check if Cilium agent is ready
    kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s &> /dev/null
    if [ $? -eq 0 ]; then
        note "✓ Cilium pods are ready"
        ((pass++))
    else
        error "✗ Cilium pods not ready within timeout"
        ((fail++))
    fi
    
    # Check Cilium status via CLI
    if kubectl -n kube-system exec -it ds/cilium -- cilium status --brief &> /dev/null; then
        note "✓ Cilium status is healthy"
        ((pass++))
    else
        error "✗ Cilium status check failed"
        ((fail++))
    fi
    
    # Remove taint
    kubectl taint nodes --all node.cilium.io/agent-not-ready:NoExecute- &> /dev/null || true
    note "✓ Removed Cilium taint from nodes"
    
    printf "\nCilium Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_gateway_api_crds() {
    header "Testing Gateway API CRDs"
    
    local pass=0
    local fail=0
    
    # Check for Gateway CRD
    if kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null; then
        note "✓ Gateway CRD exists"
        ((pass++))
    else
        error "✗ Gateway CRD not found"
        ((fail++))
    fi
    
    # Check for HTTPRoute CRD
    if kubectl get crd httproutes.gateway.networking.k8s.io &> /dev/null; then
        note "✓ HTTPRoute CRD exists"
        ((pass++))
    else
        error "✗ HTTPRoute CRD not found"
        ((fail++))
    fi
    
    # Check for GatewayClass CRD
    if kubectl get crd gatewayclasses.gateway.networking.k8s.io &> /dev/null; then
        note "✓ GatewayClass CRD exists"
        ((pass++))
    else
        error "✗ GatewayClass CRD not found"
        ((fail++))
    fi
    
    printf "\nGateway API CRD Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_gateway_resource() {
    header "Testing Gateway resource"
    
    local pass=0
    local fail=0
    local retries=30
    
    # Wait for Gateway to exist
    for i in $(seq 1 $retries); do
        if kubectl get gateway -n edge &> /dev/null; then
            break
        fi
        
        if [ $i -eq $retries ]; then
            error "✗ Gateway not found in edge namespace after ${retries} attempts"
            ((fail++))
            return $fail
        fi
        
        sleep 2
    done
    
    note "✓ Gateway resource exists in edge namespace"
    ((pass++))
    
    # Check Gateway status
    local gw_status=$(kubectl get gateway -n edge -o jsonpath='{.items[0].status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "Unknown")
    if [[ "$gw_status" == "True" ]]; then
        note "✓ Gateway status is Accepted"
        ((pass++))
    else
        error "✗ Gateway status: $gw_status (may still be initializing)"
        ((fail++))
    fi
    
    # Check if Gateway pods exist
    local gw_pods=$(kubectl get pods -n kube-system -l gateway.networking.k8s.io/gateway-name --no-headers 2>/dev/null | wc -l)
    if [[ "$gw_pods" -gt 0 ]]; then
        note "✓ Gateway pods found ($gw_pods pods)"
        ((pass++))
    else
        error "✗ No Gateway pods found"
        ((fail++))
    fi
    
    # Check if using hostNetwork
    local host_net=$(kubectl get pods -n kube-system -l gateway.networking.k8s.io/gateway-name -o jsonpath='{.items[0].spec.hostNetwork}' 2>/dev/null || echo "false")
    if [[ "$host_net" == "true" ]]; then
        note "✓ Gateway pods using hostNetwork mode"
        ((pass++))
    else
        error "✗ Gateway pods NOT using hostNetwork (found: $host_net)"
        ((fail++))
    fi
    
    printf "\nGateway Resource Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_http_connectivity() {
    header "Testing HTTP connectivity to Gateway"
    
    local pass=0
    local fail=0
    
    # Get external IP
    local external_ip=${EXTERNAL_IP:-$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)}
    
    note "Testing against IP: $external_ip"
    
    # Test local connectivity on high port (before redirect)
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 --max-time 5 | grep -q "404\|200"; then
        note "✓ Local connectivity on port 8080 working (Gateway responding)"
        ((pass++))
    else
        error "✗ Local connectivity on port 8080 failed"
        ((fail++))
    fi
    
    # Test external connectivity (after redirect)
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" http://${external_ip} --max-time 10 2>/dev/null || echo "000")
    if [[ "$http_code" == "404" ]] || [[ "$http_code" == "200" ]]; then
        note "✓ External HTTP (port 80→8080 redirect) working (HTTP $http_code)"
        ((pass++))
    else
        error "✗ External HTTP failed (HTTP $http_code)"
        ((fail++))
    fi
    
    printf "\nHTTP Connectivity Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_cert_manager() {
    header "Testing cert-manager"
    
    local pass=0
    local fail=0
    
    # Check if cert-manager namespace exists
    if kubectl get namespace cert-manager &> /dev/null; then
        note "✓ cert-manager namespace exists"
        ((pass++))
    else
        error "✗ cert-manager namespace not found"
        ((fail++))
        return $fail
    fi
    
    # Check if cert-manager pods are running
    local cm_ready=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "$cm_ready" -ge 3 ]]; then
        note "✓ cert-manager pods are running ($cm_ready/3)"
        ((pass++))
    else
        error "✗ cert-manager pods not all running: $cm_ready/3"
        ((fail++))
    fi
    
    # Check if ClusterIssuer exists
    if kubectl get clusterissuer &> /dev/null; then
        note "✓ ClusterIssuer resources found"
        ((pass++))
    else
        error "✗ No ClusterIssuer found"
        ((fail++))
    fi
    
    printf "\ncert-manager Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

test_httproutes() {
    header "Testing HTTPRoute resources"
    
    local pass=0
    local fail=0
    
    # Check if any HTTPRoutes exist
    local route_count=$(kubectl get httproute -A --no-headers 2>/dev/null | wc -l)
    if [[ "$route_count" -gt 0 ]]; then
        note "✓ HTTPRoute resources found ($route_count routes)"
        ((pass++))
    else
        error "✗ No HTTPRoute resources found"
        ((fail++))
    fi
    
    printf "\nHTTPRoute Tests: ${pass} passed, ${fail} failed\n"
    return $fail
}

run_all_tests() {
    title "Running All Gateway Tests"
    
    local total_fail=0
    
    test_iptables_rules
    total_fail=$((total_fail + $?))
    
    test_kubernetes_api
    total_fail=$((total_fail + $?))
    
    test_cilium_status
    total_fail=$((total_fail + $?))
    
    test_gateway_api_crds
    total_fail=$((total_fail + $?))
    
    test_gateway_resource
    total_fail=$((total_fail + $?))
    
    test_port_listening
    total_fail=$((total_fail + $?))
    
    test_http_connectivity
    total_fail=$((total_fail + $?))
    
    test_cert_manager
    total_fail=$((total_fail + $?))
    
    test_httproutes
    total_fail=$((total_fail + $?))
    
    title "Test Summary"
    if [[ $total_fail -eq 0 ]]; then
        note "✓✓✓ ALL TESTS PASSED ✓✓✓"
        return 0
    else
        error "✗✗✗ SOME TESTS FAILED ✗✗✗"
        return 1
    fi
}

# Quick test function for rapid iteration
quick_test() {
    header "Quick Gateway Test"
    test_iptables_rules
    test_port_listening
    test_gateway_resource
}