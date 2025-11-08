# clusters/on-site

Purpose: On-site cluster provisioning scripts and an `applications.yaml` used for cluster-specific application lists.

Key files:
- `clusters/on-site/init.sh` — on-site cluster bootstrap
- `clusters/on-site/applications.yaml` — per-cluster application configuration

Notes: On-site clusters may have different network topology and firewall constraints compared to cloud clusters. Review `obsidian/Cloud-Proxy.md` and `obsidian/Firewall Rules (Most Common in GCE).md` for related notes.
