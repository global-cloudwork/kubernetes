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
