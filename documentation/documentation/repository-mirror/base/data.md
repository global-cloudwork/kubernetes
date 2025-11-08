# base/data

Purpose: Database and data-platform kustomize paths. Holds manifests and configuration for stateful components used across the cluster.

Key files/folders:
- `base/data/kustomization.yaml` — entry for data-related kustomize paths
- Storage and access-related notes for databases and backups

Notes: Changes here affect storage and backups. Confirm storageclass and PV behavior before modifying.

How to preview:

```bash
kubectl kustomize ./base/data | kubectl apply --server-side --force-conflicts -f -
```
