#!/bin/bash
# curl --silent --show-error https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/tests/issue-7.sh | bash
# Cert-Manager + Cilium BPF Connectivity Debugger
# This script helps diagnose why cert-manager can't reach the API server through Cilium

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Cert-Manager Cilium Connectivity Debugger${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Configuration
API_SERVER_IP="10.43.0.1"
API_SERVER_PORT="443"
SERVICE_CIDR="10.43.0.0/16"
CERT_MANAGER_NS="cert-manager"

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 1. Check Cilium Status
print_header "1. Cilium Status and Configuration"
echo "Checking Cilium pods..."
kubectl get pods -n kube-system -l k8s-app=cilium -o wide

echo -e "\nCilium ConfigMap:"
kubectl get cm -n kube-system cilium-config -o yaml | grep -E "(kube-proxy-replacement|enable-host-reachable-services|host-reachable-services-protos)"

# 2. Check Service Details
print_header "2. Kubernetes API Service Details"
kubectl get svc kubernetes -o yaml

# 3. Check Cilium BPF Service Maps
print_header "3. Cilium BPF Service Maps"
echo "Getting Cilium pod on the problem node..."
NODE_NAME=$(kubectl get pod -n "$CERT_MANAGER_NS" -l app=cert-manager -o jsonpath='{.items[0].spec.nodeName}')
echo "Node: $NODE_NAME"

CILIUM_POD=$(kubectl get pod -n kube-system -l k8s-app=cilium --field-selector spec.nodeName="$NODE_NAME" -o jsonpath='{.items[0].metadata.name}')
echo "Cilium Pod: $CILIUM_POD"

echo -e "\nChecking if API service is in BPF maps..."
kubectl exec -n kube-system "$CILIUM_POD" -- cilium service list | grep -A5 "$API_SERVER_IP"

# 4. Check Host Routing
print_header "4. Host Routing Table"
echo "Checking route to API server from host..."
kubectl debug node/"$NODE_NAME" -it --image=nicolaka/netshoot -- ip route get "$API_SERVER_IP" || print_error "Could not check host routing"

# 5. Check BPF Filesystem
print_header "5. BPF Filesystem Status"
kubectl debug node/"$NODE_NAME" -it --image=nicolaka/netshoot -- mount | grep bpf || print_error "BPF not mounted"
kubectl debug node/"$NODE_NAME" -it --image=nicolaka/netshoot -- ls -la /sys/fs/bpf/ || print_error "Cannot access BPF filesystem"

# 6. Cert-Manager Pod Configuration
print_header "6. Cert-Manager Pod Configuration"
CERT_MANAGER_POD=$(kubectl get pod -n "$CERT_MANAGER_NS" -l app=cert-manager -o jsonpath='{.items[0].metadata.name}')
echo "Cert-Manager Pod: $CERT_MANAGER_POD"

echo -e "\nSecurity Context:"
kubectl get pod -n "$CERT_MANAGER_NS" "$CERT_MANAGER_POD" -o jsonpath='{.spec.securityContext}' | jq '.'

echo -e "\nContainer Security Context:"
kubectl get pod -n "$CERT_MANAGER_NS" "$CERT_MANAGER_POD" -o jsonpath='{.spec.containers[0].securityContext}' | jq '.'

echo -e "\nCapabilities:"
kubectl get pod -n "$CERT_MANAGER_NS" "$CERT_MANAGER_POD" -o jsonpath='{.spec.containers[0].securityContext.capabilities}' | jq '.'

# 7. Test Connectivity from Different Contexts
print_header "7. Connectivity Tests"

echo "Test 1: From privileged debug pod on same node..."
kubectl run test-privileged --rm -i --restart=Never \
  --image=nicolaka/netshoot \
  --overrides="{
    \"spec\": {
      \"nodeSelector\": {\"kubernetes.io/hostname\": \"$NODE_NAME\"},
      \"containers\": [{
        \"name\": \"test\",
        \"image\": \"nicolaka/netshoot\",
        \"stdin\": true,
        \"tty\": true,
        \"command\": [\"timeout\", \"5\", \"curl\", \"-k\", \"-v\", \"https://$API_SERVER_IP:$API_SERVER_PORT\"],
        \"securityContext\": {
          \"privileged\": true
        }
      }]
    }
  }" 2>&1 | tee /tmp/test-privileged.log

if grep -q "401" /tmp/test-privileged.log || grep -q "Unauthorized" /tmp/test-privileged.log; then
    print_success "Privileged pod can connect (got 401 auth error - connection successful)"
else
    print_error "Privileged pod cannot connect"
fi

echo -e "\nTest 2: From unprivileged pod matching cert-manager context..."
CERT_MANAGER_UID=$(kubectl get pod -n "$CERT_MANAGER_NS" "$CERT_MANAGER_POD" -o jsonpath='{.spec.securityContext.runAsUser}')
CERT_MANAGER_GID=$(kubectl get pod -n "$CERT_MANAGER_NS" "$CERT_MANAGER_POD" -o jsonpath='{.spec.securityContext.runAsGroup}')

kubectl run test-unprivileged --rm -i --restart=Never \
  --image=nicolaka/netshoot \
  --overrides="{
    \"spec\": {
      \"nodeSelector\": {\"kubernetes.io/hostname\": \"$NODE_NAME\"},
      \"securityContext\": {
        \"runAsUser\": ${CERT_MANAGER_UID:-1000},
        \"runAsGroup\": ${CERT_MANAGER_GID:-1000},
        \"runAsNonRoot\": true
      },
      \"containers\": [{
        \"name\": \"test\",
        \"image\": \"nicolaka/netshoot\",
        \"stdin\": true,
        \"tty\": true,
        \"command\": [\"timeout\", \"5\", \"curl\", \"-k\", \"-v\", \"https://$API_SERVER_IP:$API_SERVER_PORT\"],
        \"securityContext\": {
          \"allowPrivilegeEscalation\": false,
          \"capabilities\": {
            \"drop\": [\"ALL\"]
          }
        }
      }]
    }
  }" 2>&1 | tee /tmp/test-unprivileged.log

if grep -q "401" /tmp/test-unprivileged.log || grep -q "Unauthorized" /tmp/test-unprivileged.log; then
    print_success "Unprivileged pod can connect (got 401 auth error - connection successful)"
elif grep -q "timeout" /tmp/test-unprivileged.log; then
    print_error "Unprivileged pod timeout - matches cert-manager issue!"
else
    print_warning "Unprivileged pod had different error"
fi

# 8. Check Cilium Host-Reachable Services
print_header "8. Cilium Host-Reachable Services Configuration"
echo "Checking if host-reachable-services is enabled..."
kubectl exec -n kube-system "$CILIUM_POD" -- cilium config | grep -i "host-reachable"

# 9. Check for AppArmor/SELinux
print_header "9. Security Module Status"
echo "Checking AppArmor status on node..."
kubectl debug node/"$NODE_NAME" -it --image=nicolaka/netshoot -- cat /sys/module/apparmor/parameters/enabled 2>/dev/null || echo "AppArmor status unknown"

echo -e "\nChecking SELinux status on node..."
kubectl debug node/"$NODE_NAME" -it --image=nicolaka/netshoot -- getenforce 2>/dev/null || echo "SELinux not present or disabled"

# 10. Summary and Recommendations
print_header "10. Summary and Recommended Actions"

echo -e "\n${YELLOW}Based on the tests above, here are potential fixes:${NC}\n"

echo "1. Enable Cilium host-reachable-services:"
echo "   kubectl -n kube-system edit cm cilium-config"
echo "   Add: enable-host-reachable-services: 'true'"
echo "   Restart Cilium pods"

echo -e "\n2. Add NET_BIND_SERVICE capability to cert-manager:"
echo "   Edit cert-manager deployment to add:"
echo "   securityContext:"
echo "     capabilities:"
echo "       add: [\"NET_BIND_SERVICE\"]"

echo -e "\n3. If using Cilium host-reachable-services-protos, ensure it includes tcp:"
echo "   host-reachable-services-protos: tcp,udp"

echo -e "\n4. Check Cilium endpoint status:"
echo "   kubectl exec -n kube-system $CILIUM_POD -- cilium endpoint list"

echo -e "\n5. Verify no NetworkPolicies are blocking cert-manager:"
echo "   kubectl get netpol -A"

echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}Debug Complete${NC}"
echo -e "${BLUE}================================================${NC}"
