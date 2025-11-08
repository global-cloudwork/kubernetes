# example

Purpose: Example/kitchen-sink application used for demos or experimentation. Inspect this folder to see how sample apps are structured.

Key files (if present):
- `applications/example/kustomization.yaml` — kustomize entry for the example app
- `applications/example/namespace.yaml`
- `applications/example/httproute.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/example | kubectl apply --server-side --force-conflicts -f -
```

Notes: This folder is a good reference when adding new apps; follow its layout for namespace, httproute, and kustomize patches.
