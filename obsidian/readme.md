# 📘 Repository Directory & Documentation Index

This document serves as a starting point for navigating this repository and it's files.

## Documentation Directory Structure

The `obsidian/documentation/repository-mirror/` directory. 
- mirrors the folder structure of this repository
- does not mirror the files, only the directory hierarchy is preserved
- each folder contains a markdown file describing it's folder and it's contents 

For example to research a file `core/edge/gateway.yaml` you should first read `obsidian/documentation/repository-mirror/core/edge/edge.md` because it contains information about each file in `core/edge/` including `core/edge/gateway.yaml`.

**Example:**  
`applications/argocd/` ↔️ `obsidian/directory-mirror/applications/argocd/` → contains `argocd.md` describing that component.

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

