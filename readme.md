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

- lower case
- letters, numbers, and hyphens only
- manifests and other declarative files describe what the file is
    - application-set.yaml contains manifests with type: applicationset 
- scripts or processes describe what the file does
    - upload-env.sh uploads an env to cloud storage
    - if called as a function, you must be able to understand what it does

