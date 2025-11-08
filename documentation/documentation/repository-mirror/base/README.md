# base

Purpose: Cluster-wide kustomize pieces and pinned CRDs. The `base/` kustomize paths define cluster bootstrap and shared resources used by all clusters.

Key folders and files:
- `base/kustomization.yaml` — central CRDs and bootstrap resources (cert-manager, Gateway API, Cilium, ArgoCD).
- `base/core/` — core services (Argocd ApplicationSet, Cilium, cluster-wide controllers).
- `base/data/`, `base/edge/`, `base/tenant/` — grouped kustomize paths deployed by the ApplicationSet.

Why this matters: changes under `base/` are repository-wide and can affect every cluster. Coordinate with maintainers before updating CRDs or core controllers.

How to preview:

```bash
kubectl kustomize ./base | kubectl apply --server-side --force-conflicts -f -
```
