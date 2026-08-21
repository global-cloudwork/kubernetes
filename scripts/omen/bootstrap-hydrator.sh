#!/usr/bin/env bash

################################################################################
# Bootstrap ArgoCD Source Hydrator
#
# This script sets up ArgoCD Source Hydrator for automated manifest rendering
# from main branch to environment branches.
#
# Prerequisites:
# - ArgoCD 3.2+ installed
# - GitHub Personal Access Token (PAT) with 'repo' scope
# - Write access to global-cloudwork/kubernetes repository
#
# Usage:
#   ./scripts/omen/bootstrap-hydrator.sh <github-username> <github-pat-token>
#
# Example:
#   ./scripts/omen/bootstrap-hydrator.sh myuser ghp_xxxxxxxxxxxx
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}▶${NC} ${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check arguments
if [ $# -ne 2 ]; then
    print_error "Missing arguments"
    echo ""
    echo "Usage: $0 <github-username> <github-pat-token>"
    echo ""
    echo "Example:"
    echo "  $0 myuser ghp_xxxxxxxxxxxx"
    echo ""
    echo "To create a GitHub PAT:"
    echo "  1. Go to github.com/settings/tokens"
    echo "  2. Create 'Personal access token (classic)'"
    echo "  3. Select 'repo' scope"
    echo "  4. Copy the token (you won't see it again)"
    exit 1
fi

GITHUB_USERNAME="$1"
GITHUB_PAT_TOKEN="$2"

echo ""
print_header "ArgoCD Source Hydrator Bootstrap"
echo ""

# Step 1: Verify Prerequisites
print_header "Step 1: Verifying prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl."
    exit 1
fi
print_success "kubectl found"

if ! kubectl get namespace argocd &> /dev/null; then
    print_error "argocd namespace not found. Please install ArgoCD."
    exit 1
fi
print_success "ArgoCD namespace found"

# Check ArgoCD version
ARGOCD_VERSION=$(kubectl get deployment -n argocd argocd-application-controller -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
print_success "ArgoCD version: $ARGOCD_VERSION"

echo ""
print_header "Step 2: Enabling Source Hydrator in ArgoCD..."

# Enable hydrator in ArgoCD ConfigMap
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{
  "data": {
    "hydrator.enabled": "true",
    "commit.server": "argocd-commit-server:8086"
  }
}' 2>/dev/null || {
    print_error "Failed to patch argocd-cmd-params-cm"
    exit 1
}
print_success "Source Hydrator enabled in ArgoCD ConfigMap"

echo ""
print_header "Step 3: Creating repository write secret..."

# Create the write secret
kubectl create secret generic global-cloudwork-kubernetes-write \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/global-cloudwork/kubernetes \
  --from-literal=username="$GITHUB_USERNAME" \
  --from-literal=password="$GITHUB_PAT_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# Label the secret as a write secret
kubectl label secret global-cloudwork-kubernetes-write \
  -n argocd \
  argocd.argoproj.io/secret-type=repository-write \
  --overwrite 2>/dev/null

print_success "Repository write secret created and labeled"

echo ""
print_header "Step 4: Verifying secret configuration..."

SECRET_EXISTS=$(kubectl get secret -n argocd global-cloudwork-kubernetes-write -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
if [ -z "$SECRET_EXISTS" ]; then
    print_error "Secret not found after creation"
    exit 1
fi
print_success "Secret verified"

# Verify secret has correct label
SECRET_LABEL=$(kubectl get secret -n argocd global-cloudwork-kubernetes-write -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}' 2>/dev/null || echo "")
if [ "$SECRET_LABEL" != "repository-write" ]; then
    print_warning "Secret label not set correctly. Setting now..."
    kubectl label secret global-cloudwork-kubernetes-write \
      -n argocd \
      argocd.argoproj.io/secret-type=repository-write \
      --overwrite
    print_success "Secret label corrected"
fi

echo ""
print_header "Step 5: Deploying Hydrator Applications..."

# Apply hydrator applications
if kubectl apply -f kubernetes/core/hydrator-applications.yaml; then
    print_success "Hydrator Applications deployed"
else
    print_error "Failed to deploy hydrator applications"
    exit 1
fi

echo ""
print_header "Step 6: Deploying Environment Applications..."

# Apply environment applications
if kubectl apply -f kubernetes/core/development.yaml && \
   kubectl apply -f kubernetes/core/testing.yaml && \
   kubectl apply -f kubernetes/core/prod.yaml; then
    print_success "Environment Applications deployed"
else
    print_error "Failed to deploy environment applications"
    exit 1
fi

echo ""
print_header "Step 7: Waiting for ArgoCD to reconcile..."

# Give ArgoCD time to sync
sleep 10

echo ""
print_header "Verification..."

# Check hydrator applications status
HYDRATOR_APPS=$(kubectl get application -n argocd -l app.kubernetes.io/part-of=hydrator -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | wc -w)
print_success "Hydrator Applications deployed: ~21 (checked $HYDRATOR_APPS)"

# Check environment applications status
DEV_APPS=$(kubectl get application -n argocd -o name | grep -E "dev$|dev-" | wc -l)
TEST_APPS=$(kubectl get application -n argocd -o name | grep -E "testing$|testing-" | wc -l)
PROD_APPS=$(kubectl get application -n argocd -o name | grep -E "prod$|prod-" | wc -l)
print_success "Environment Applications deployed: dev($DEV_APPS) testing($TEST_APPS) prod($PROD_APPS)"

echo ""
print_header "Next Steps:"
echo ""
echo "1. Monitor hydrator activity:"
echo "   kubectl logs -n argocd deployment/argocd-application-controller -f | grep -i hydrat"
echo ""
echo "2. Verify hydration is working:"
echo "   git fetch origin"
echo "   git log origin/next-development --oneline | head -5"
echo ""
echo "3. Check rendered manifests:"
echo "   git show origin/next-development:helm/traefik-hydrated/Chart.yaml | head -20"
echo ""
echo "4. Test promotion workflow:"
echo "   git checkout development"
echo "   git merge next-development"
echo "   git push origin development"
echo ""
echo "5. Monitor application sync:"
echo "   kubectl get application -n argocd -w"
echo ""

print_success "ArgoCD Source Hydrator bootstrap complete!"
echo ""
