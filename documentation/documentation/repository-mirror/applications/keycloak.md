# keycloak

Purpose: Identity and access management provider. Deployed via a kustomize path under `applications/keycloak`.

Key files in repository:
- `applications/keycloak/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/keycloak | kubectl apply --server-side --force-conflicts -f -
```

Notes: Check realm and client configuration referenced by the chart or additional manifests.
