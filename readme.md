# 📘 Repository Directory & Documentation Index

This document serves as a starting point for navigating this repository and it's files.

## The documentation directory imitates the repo's directory hierarchy

The `obsidian/documentation/repository-mirror/` directory mirrors the folder structure of this repository.
- It mirrors only the directory hierarchy — not the file contents.
- Each mirrored folder contains a markdown file that documents that folder and its contents.


## Obsidian (mirrored docs)

This repository includes an `obsidian/` folder containing mirrored documentation and notes. The most relevant mirror is:

- `obsidian/documentation/repository-mirror/` — directory-only mirror with a markdown file per folder describing its purpose and key files.

Top-level notes in `obsidian/` that are useful to developers include:

- `Applications.base` — overview of application layout and kustomize patterns
- `cert manager.md` — notes about cert-manager usage and CRDs
- `Cilium System Requirements.md` — Cilium/CNI requirements and constraints
- `Cloud-Proxy.md`, `DNSO1.md`, `Firewall Rules (Most Common in GCE).md` — network and cloud-specific notes

Keep the mirrored docs up-to-date when you add or rename directories: the mirror preserves structure so readers can find documentation by path. Update `obsidian/documentation/repository-mirror/<path>/<folder>.md` to document new folders.

For quick reference, to find documentation for a file at `applications/open-webui/httproute.yaml` open `obsidian/documentation/repository-mirror/applications/open-webui/open-webui.md` (or the parent folder doc) which will describe the purpose and where to look next.

### `base` Directory

### `base` Directory

This directory contains all of the kustomization files needed to deploy the cluster. 
- Base's kustomize file deploys CRDs
- Core's deploys cilium, argocd, and an application for Edge, Tenant, and Data.
- Edge contains the gateway, cluster issuer, and networking files.
- Data contains details about the database and data access.
- Tenant deploys each app by running `applications/*/kustomization.yaml`

### `scripts` Directory

Contains bash scripts used as tools.

### `clusters` Directory

Contains a directory per cluster, containing an RKE2 configuration file, init.sh, and other scripts needed to prevision or deploy the cluster.

### `applications` Directory

Contains kustomization.yaml files that each deploy a single helm chart as well as resources: httproutes, namespaces, and other manifests needed to deploy each application. 

## Direcotry Naming Conventions

- lower case
- letters, numbers, and hyphens only
- describes the folder contents
- plural if a set of things
- new directories should be mirrored like above

## File Naming Conventions
# File Naming Conventions

- lower case
- letters, numbers, and hyphens only
- manifests and other declarative files describe what the file is
    - application-set.yaml contains manifests with type: applicationset
- scripts or processes describe what the file does
    - upload-env.sh uploads an env to cloud storage
    - if called as a function, you must be able to understand what it does


## AI agent / Copilot instructions (moved from `.github/copilot-instructions.md`)

Purpose
Action-oriented guidance for an AI coding agent to be productive in this repository.

Keep this short and specific — follow the repo's kustomize-first deployment model, ArgoCD-driven sync, and cluster scripts.

Big-picture architecture (short)
- Kustomize directories under `base/` and `applications/` define the desired cluster state. `base/core/application-set.yaml` is the ArgoCD ApplicationSet that deploys selected `base/*` paths to clusters.
- Gateway API (HTTPRoute) is used for ingress; `applications/*/httproute.yaml` files expose services.
- Cilium is the CNI and policy provider; CRDs and pinned manifests live in `base/kustomization.yaml`.

Key files & where to look (examples)
- `base/kustomization.yaml` — central CRDs and bootstrap resources. Changing this impacts all clusters.
- `base/core/application-set.yaml` — Argo ApplicationSet that deploys `base/data`, `base/edge`, `base/tenant`.
- `applications/<app>/kustomization.yaml` — per-application manifests. Typical companion files: `namespace.yaml`, `httproute.yaml`, and optional `values.yaml` for Helm values.
- `scripts/upload-key.sh` — push `dns-key.json` / `gce-key.json` content into cloud secrets.
- `scripts/kubernetes.sh` — kubectl helpers used by tests and scripts (read for patterns like `wait_for`, `unfinished_pods`).
- `clusters/*/init.sh`, `clusters/*/startup-script.sh` — cluster bootstrap logic; modifying these changes cluster initialization.

Developer workflows & concrete commands
- Deploy a kustomize path (used by tasks):

  kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes?ref=main" | kubectl apply --server-side --force-conflicts -f -

- ArgoCD local UI (workspace task): `http://localhost:30080` (task: "Argocd in Browser").
- Use `scripts/upload-key.sh` to update cloud secrets from `dns-key.json` / `gce-key.json` rather than committing secrets.

Conventions & patterns to follow (repo-specific)
- Kustomize-first: add resources by creating or editing `applications/<app>/kustomization.yaml` and letting ArgoCD/kustomize sync.
- Application dir structure: lowercase, hyphen-separated names. Include `kustomization.yaml` and `namespace.yaml`. Use `httproute.yaml` to expose via Gateway API.
- Helm values (when used) live alongside kustomize in `applications/<app>/values.yaml`.
- CRDs and cluster-wide resources are pinned in `base/kustomization.yaml` — treat updates here as repo-wide and coordinate with maintainers.

When adding or editing an app (quick checklist)
1. Create `applications/<app>/kustomization.yaml` and `namespace.yaml`.
2. Add `httproute.yaml` if the service needs external HTTP exposure (follow `applications/open-webui/httproute.yaml` example).
3. Add `values.yaml` if using a Helm chart.
4. Test locally by rendering the kustomize path then applying the output (see deploy command above) or push branch and let ArgoCD sync.

Integration points & external dependencies
- ArgoCD (ApplicationSet) reads this Git repo directly — changes to `applications/*` and `base/*` are picked up by Argo.
- External CRD manifests (cert-manager, Gateway API, Cilium) are referenced from `base/kustomization.yaml` — these are intentionally pinned.
- GCP secrets and DNS keys: `dns-key.json` and `gce-key.json` at repo root; use `scripts/upload-key.sh` to upload them to cloud secrets.

Troubleshooting & tests
- Quick ingress check: `tests/ingress.sh` exists for verifying HTTPRoutes and ingress.
- Use `scripts/kubernetes.sh` helper functions (e.g., `wait_for`) when automating readiness checks.

What NOT to change lightly
- Avoid broad edits to `base/kustomization.yaml` or CRD versions without coordination — these affect the whole fleet.
- Don't commit secrets (use `scripts/upload-key.sh` instead).

If something is missing
- Ask the maintainer which cluster(s) a change targets, desired pruning behavior, and whether changes should be applied via ArgoCD or one-off kubectl applies.

---
If you'd like, I can: (1) open a PR with this file, (2) add a small README snippet in `applications/` showing a kustomize example, or (3) add a test workflow to validate kustomize renders. Which would you like next?

