#!/usr/bin/env bash

set -e

NAMESPACE="argocd"

echo "🔐 Fetching Argo CD credentials from namespace: $NAMESPACE"
echo ""

# Username is always admin for default install
echo "Username:"
echo "admin"
echo ""

# Get password from Kubernetes secret
echo "Password:"
kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

echo ""
echo ""
echo "🌐 UI:"
echo "http://localhost:30080"