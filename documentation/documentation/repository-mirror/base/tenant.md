# base/tenant

Purpose: Tenant-scoped application sets and application templates. This path contains kustomize entries and an `application-set.yaml` used to deploy tenant applications.

Key files:
- `base/tenant/kustomization.yaml`
- `base/tenant/application-set.yaml` — tenant ApplicationSet definitions

Notes: Tenant manifests determine what apps are available per-tenant/cluster. Coordinate tenant-level changes with platform operators.

How to preview:

```bash
kubectl kustomize ./base/tenant | kubectl apply --server-side --force-conflicts -f -
```
