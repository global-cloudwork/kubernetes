# scripts

Purpose: Collection of helper bash scripts used for provisioning, key uploads, and kubernetes helpers.

Key scripts:
- `scripts/upload-key.sh` — upload `dns-key.json` / `gce-key.json` content into cloud secrets (do not commit secrets instead use this script).
- `scripts/kubernetes.sh` — kubectl helper functions used by tests and automation (`wait_for`, `unfinished_pods`, etc.).
- `scripts/general.sh` — general purpose helpers used by other scripts.

Usage tip: Many scripts are sourced by workspace tasks. Review the script header comments to see required environment variables before running.
