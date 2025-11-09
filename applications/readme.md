# actualbudget

Purpose: Budgeting application deployed under `applications/actualbudget`.

Key files:
- `applications/actualbudget/kustomization.yaml`
- `applications/actualbudget/httproute.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/actualbudget | kubectl apply --server-side --force-conflicts -f -
```

````

````markdown
# cockatrice

Purpose: Card game server (Cockatrice) deployed via `applications/cockatrice`.

Key files:
- `applications/cockatrice/` (kustomize path)

How to preview/apply:

```bash
kubectl kustomize ./applications/cockatrice | kubectl apply --server-side --force-conflicts -f -
```

````

````markdown
# erpnext

Purpose: ERP system (erpnext) deployed via the kustomize path `applications/erpnext`.

Key files:
- `applications/erpnext/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/erpnext | kubectl apply --server-side --force-conflicts -f -
```

Notes: ERP systems are stateful; check storage and backup patterns before changing defaults.

````

````markdown
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

````

````markdown
# foundry-vtt

Purpose: Game server application (Foundry VTT) deployed via kustomize path under `applications/foundry-vtt`.

Key files:
- `applications/foundry-vtt/` (kustomize path and optional httproute)

How to preview/apply:

```bash
kubectl kustomize ./applications/foundry-vtt | kubectl apply --server-side --force-conflicts -f -
```

````

````markdown
# homepage

Purpose: Static or simple web-facing application (project home page) deployed under `applications/homepage`.

Key files:
- `applications/homepage/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/homepage | kubectl apply --server-side --force-conflicts -f -
```

````

````markdown
# keycloak

Purpose: Identity and access management provider. Deployed via a kustomize path under `applications/keycloak`.

Key files in repository:
- `applications/keycloak/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/keycloak | kubectl apply --server-side --force-conflicts -f -
```

Notes: Check realm and client configuration referenced by the chart or additional manifests.

````

````markdown
# longhorn

Purpose: Longhorn storage operator manifests and configuration used for persistent volumes.

Key files:
- `applications/longhorn/` (kustomize path for longhorn)

How to preview/apply:

```bash
kubectl kustomize ./applications/longhorn | kubectl apply --server-side --force-conflicts -f -
```

Notes: Modifying storage classes or settings here affects PVCs cluster-wide.

````

````markdown
# n8n

Purpose: Workflow automation application (n8n) deployed via kustomize/helm.

Key files:
- `applications/n8n/kustomization.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/n8n | kubectl apply --server-side --force-conflicts -f -
```

````

````markdown
# neo4j

Purpose: Graph database application deployed via kustomize/helm and exposed with an HTTPRoute for the management UI (if present).

Key files in repository:
- `applications/neo4j/kustomization.yaml`
- `applications/neo4j/httproute.yaml` (networking exposure)
- `applications/neo4j/namespace.yaml`

How to preview/apply:

```bash
kubectl kustomize ./applications/neo4j | kubectl apply --server-side --force-conflicts -f -
```

Notes: Check persistent volume and storage class settings in the kustomize path when working with database workloads.

````

````markdown
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

````

````markdown
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

````

*** End Patch