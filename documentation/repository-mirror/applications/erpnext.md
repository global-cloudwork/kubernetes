# erpnext

Purpose: ERP system (erpnext) deployed via the kustomize path `applications/erpnext`.

Key files:
- `applications/erpnext/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/erpnext | kubectl apply --server-side --force-conflicts -f -
```

Notes: ERP systems are stateful; check storage and backup patterns before changing defaults.
