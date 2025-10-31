---
title: "Deployment Script / Cluster Configuration"
script_name: "startup-script.sh"
steps:
  - "Export environment variables file and instance metadata for IPs"
  - "Update system packages via apt"
  - "Install tools: WireGuard, K9s, Helm3, RKE2"
  - "Create directories for RKE2 and server manifests"
  - "Pull RKE2 configuration from monorepo"
  - "Substitute environment variables (including CNI settings) into RKE2 config"
  - "Enable and start the RKE2 service"
  - "Link kubectl to user-local bin"
  - "Create .kube directories and copy kubeconfig with proper ownership"
  - "Flatten all kubeconfigs into a single file"
  - "Deploy manifests: gateway, TLSRoute CRDs, Argo project manifests"
  - "Wait for CRDs to be ready before proceeding"
---

# Deployment Script / Cluster Configuration

This document describes the startup script that configures and boots the Kubernetes node, installs necessary dependencies, and deploys initial cluster manifests.
