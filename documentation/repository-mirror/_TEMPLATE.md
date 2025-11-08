# <folder> (repository mirror)

Purpose: one short sentence describing the folder's role in the repo.

Key files:
- `kustomization.yaml` — what this kustomize path deploys (if present)
- `namespace.yaml` — target namespace(s)
- `httproute.yaml` — Gateway API exposure (if present)
- `values.yaml` — Helm values for the chart (if present)

How to render / apply:

```bash
kubectl kustomize "./<path/to/folder>" | kubectl apply --server-side --force-conflicts -f -
```

Notes / gotchas:
- Mention any cluster-wide impact (CRDs, cluster roles, etc.) or special prerequisites (e.g., cert-manager, Cilium).

Maintainer: add name or team here.
