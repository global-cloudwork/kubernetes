# clusters

Purpose: Per-cluster configuration and bootstrap scripts. Each cluster directory contains the cluster-specific init scripts and any machine/startup scripts.

Key folders:
- `clusters/cloud-proxy/` — cloud-proxy specific startup scripts (`init.sh`, `reuse-instance.sh`, `startup-script.sh`).
- `clusters/on-site/` — on-site cluster scripts and `applications.yaml` used by cluster provisioning.

Notes:
- Changes in cluster folders affect only that cluster but may be relied on by CI or provisioning tooling. Update with caution and test on a disposable cluster if possible.
