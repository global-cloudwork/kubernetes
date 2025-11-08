# homepage

Purpose: Static or simple web-facing application (project home page) deployed under `applications/homepage`.

Key files:
- `applications/homepage/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/homepage | kubectl apply --server-side --force-conflicts -f -
```
