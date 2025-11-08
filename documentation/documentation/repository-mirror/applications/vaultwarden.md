# vaultwarden

Purpose: Password-management self-hosted app. Typically deployed with a namespace, httproute and helm values.

Key files in repository:
- `applications/vaultwarden/kustomization.yaml`
- `applications/vaultwarden/httproute.yaml`
- `applications/vaultwarden/namespace.yaml`
- `applications/vaultwarden/values.yaml` — chart values used by the helm release

How to preview/apply:

```bash
kubectl kustomize ./applications/vaultwarden | kubectl apply --server-side --force-conflicts -f -
```

Notes: Values are stored alongside kustomize to make PR reviews easier.
