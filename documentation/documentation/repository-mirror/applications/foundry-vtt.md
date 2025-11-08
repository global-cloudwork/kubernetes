# foundry-vtt

Purpose: Game server application (Foundry VTT) deployed via kustomize path under `applications/foundry-vtt`.

Key files:
- `applications/foundry-vtt/` (kustomize path and optional httproute)

How to preview/apply:

```bash
kubectl kustomize ./applications/foundry-vtt | kubectl apply --server-side --force-conflicts -f -
```
