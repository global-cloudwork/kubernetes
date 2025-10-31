# 📘 Repository Directory & Documentation Index

This document serves as a starting point for navigating this repository and it's files.

## The documentation directory imitates the repo's directory hierarchy

The `obsidian/documentation/repository-mirror/` directory. 
- mirrors the folder structure of this repository
- does not mirror the files, only the directory hierarchy is preserved
- each folder contains a markdown file describing it's folder and it's contents 

For example to research a file `core/edge/gateway.yaml` you should first read `obsidian/documentation/repository-mirror/core/edge/edge.md` because it contains information about each file in `core/edge/` including `core/edge/gateway.yaml`.

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

