# actualbudget

Purpose: Budgeting application deployed under `applications/actualbudget`.

Key files:
- `applications/actualbudget/kustomization.yaml`
- `applications/actualbudget/httproute.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/actualbudget | kubectl apply --server-side --force-conflicts -f -
```
