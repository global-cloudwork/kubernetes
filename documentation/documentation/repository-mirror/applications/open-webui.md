# open-webui

Purpose: Web UI application exposed via Gateway API.

Key files in repository:
- `applications/open-webui/kustomization.yaml` — kustomize path for the app
- `applications/open-webui/httproute.yaml` — HTTPRoute for external exposure
- `applications/open-webui/namespace.yaml` — target namespace

How to preview/apply:

```bash
kubectl kustomize ./applications/open-webui | kubectl apply --server-side --force-conflicts -f -
```

Where to look next: helm values (if added) will appear as `applications/open-webui/values.yaml`. Check `base/core/application-set.yaml` to see how apps are selected for clusters.
