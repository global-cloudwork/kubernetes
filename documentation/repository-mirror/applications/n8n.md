# n8n

Purpose: Workflow automation application (n8n) deployed via kustomize/helm.

Key files:
- `applications/n8n/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/n8n | kubectl apply --server-side --force-conflicts -f -
```
