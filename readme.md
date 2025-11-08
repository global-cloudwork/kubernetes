# 📘 Repository Directory & Documentation Index

This document contains instructions on how to navigate the documentation.

## Users teritory

<!-- USER-COMMENTS-START (do not change) -->

architecture: bash, rke2, cilium installed using helm

core applications: cilium,cert-manager,argocd

tenant applications: actualbudget,cockatrice,erpnext,example,foundry-vtt,homepage,keycloak,longhorn,n8n,neo4j,open-webui,vaultwarden

networking: cluster issuer for gateway annotation 

<!-- USER-COMMENTS-END (do not change) -->


## Repository Structure and Documentation

.
├── applications
├── base
│   ├── core
│   ├── data
│   ├── edge
│   └── tenant
├── clusters
├── documentation
├── scripts
├── tests

### Directory Overview

`applications/` description:
Contains application deployment configurations, including 

environment-specific manifests and Helm values for deploying tenant and core applications.
- `base/`: Stores foundational deployment manifests for cluster setup:
    - `core/`: Core components such as `cilium` and `argocd`.
    - `data/`: Data-related configurations.
    - `edge/`: Edge deployment manifests.
    - `tenant/`: Tenant application layouts and resources.
- `clusters/`: Per-cluster configuration scripts and initialization procedures.
- `documentation/`: Documentation files, mirrors of repository structure, and key technical notes.
- `scripts/`: Bash scripts for automation tasks, cluster management, and secrets handling.
- `tests/`: Test scripts and test-related configurations for validating deployments.


- The `/documentation/repository-mirror/` directory mirrors the repository's folder hierarchy, documenting only structure, not file content.
- Mirrored docs must be updated when directories are added or renamed, maintaining consistency.
- The `obsidian/` folder contains mirrored documentation and developer notes, including key documents:
    - `Applications.base.md`: application layout and kustomize patterns
    - `cert-manager.md`: cert-manager usage and CRDs
    - `Cilium System Requirements.md`: Cilium/CNI requirements
    - `Cloud-Proxy.md`, `DNSO1.md`, `Firewall Rules (Most Common in GCE).md`: networking notes

## Repository Structure

- `base/`: Deployment manifests for cluster setup, including CRDs, core applications (`cilium`, `argocd`), Edge, Data, and Tenant apps.
- `scripts/`: Bash tools for cluster and secret management.
- `clusters/`: Per-cluster configurations, scripts, and init procedures.
- `applications/`: Application deployment configs, with `kustomization.yaml`, `namespace.yaml`, `httproute.yaml`, and optional Helm values files.

## Naming Standards

- Directory names: lowercase, hyphens, descriptive, plural for sets.
- File names: lowercase, hyphens, reflecting their function.
- Kubernetes manifests are named after their types: e.g., `deployment.yaml`, `service.yaml`, `ingress.yaml`, corresponding to deployment, service, ingress resources.

## Key Files and Usage

- `base/kustomization.yaml`: central CRD and bootstrap resources.
- `base/core/application-set.yaml`: deploys core components via ArgoCD.
- Application-specific `kustomization.yaml` and related files handle deployment.
- Scripts like `upload-key.sh` and `kubernetes.sh` assist with secret management and cluster interactions.
- Cluster bootstrap via `clusters/*/init.sh`.


