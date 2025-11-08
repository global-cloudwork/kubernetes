# longhorn

Purpose: Longhorn storage operator manifests and configuration used for persistent volumes.

Key files:
- `applications/longhorn/` (kustomize path for longhorn)

How to preview/apply:

```bash
kubectl kustomize ./applications/longhorn | kubectl apply --server-side --force-conflicts -f -
```

Notes: Modifying storage classes or settings here affects PVCs cluster-wide.
