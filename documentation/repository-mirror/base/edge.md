# base/edge

Purpose: Networking and ingress components for the cluster (Gateway API resources, TLS, and gateway glue).

Key files:
- `base/edge/gateway.yaml` — Gateway resource used by clusters
- `base/edge/certificate.yaml` — cluster certificates or ACME issuer bindings
- `base/edge/kustomization.yaml` — composition for edge resources

Why it matters: Edge changes impact ingress behavior and TLS for all apps. Validate HTTPRoute changes with `tests/ingress.sh` before wide rollouts.

How to preview:

```bash
kubectl kustomize ./base/edge | kubectl apply --server-side --force-conflicts -f -
```
