# base/core

Purpose: core cluster services and the ArgoCD ApplicationSet that drives deployments across clusters.

Key files:
- `base/core/application-set.yaml` — ApplicationSet that deploys `base/data`, `base/edge`, and `base/tenant` to clusters.
- `base/core/kustomization.yaml` — composition for core resources.

Important notes:
- The ApplicationSet is the canonical automation that reads `applications/*` and `base/*` and creates ArgoCD Applications. Changing it changes what gets deployed.
- CRDs referenced here (cert-manager, Gateway API, Cilium) are intentionally pinned. Updating CRD versions should be coordinated.
