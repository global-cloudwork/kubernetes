# cockatrice

Purpose: Card game server (Cockatrice) deployed via `applications/cockatrice`.

Key files:
- `applications/cockatrice/` (kustomize path)

How to preview/apply:

```bash
kubectl kustomize ./applications/cockatrice | kubectl apply --server-side --force-conflicts -f -
```
