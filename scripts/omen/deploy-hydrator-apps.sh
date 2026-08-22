#!/usr/bin/env bash

################################################################################
# Deploy Hydrator Applications via Kubectl
#
# This script creates all 21 hydrator applications by piping to kubectl apply.
# Alternative to: kubernetes/core/hydrator-applications.yaml
#
# Usage: ./scripts/omen/deploy-hydrator-apps.sh
#
# This demonstrates the clean manual approach to deploying hydrator apps.
################################################################################

set -e

APPS=("traefik" "argocd" "cert-manager" "authentik" "n8n" "neo4j" "homepage")
REPO="https://github.com/global-cloudwork/kubernetes"

echo "Deploying Hydrator Applications..."
echo ""

for app in "${APPS[@]}"; do
  for env_pair in "dev:development" "testing:testing" "prod:live-production"; do
    IFS=: read -r short long <<< "$env_pair"
    next="next-$long"

    echo "Creating: hydrator-${app}-${short} → ${next}"

    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hydrator-${app}-${short}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO}
    targetRevision: HEAD
    path: helm/${app}
    helm:
      releaseName: ${app}
      valuesFiles:
        - values.yaml
        - values-${short}.yaml
  destination:
    server: https://kubernetes.default.svc
  sourceHydrator:
    hydrateTo:
      targetBranch: ${next}
    syncSource:
      targetBranch: ${long}
      path: helm/${app}-hydrated
  syncPolicy:
    syncOptions:
      - PrunePropagationPolicy=foreground
      - PruneLast=true
EOF
  done
done

echo ""
echo "✓ All 21 hydrator applications deployed successfully"
