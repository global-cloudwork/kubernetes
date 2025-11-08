# clusters/cloud-proxy

Purpose: Cloud proxy cluster helper scripts and reusable instance tooling.

Key files:
- `clusters/cloud-proxy/init.sh` — cluster init logic
- `clusters/cloud-proxy/reuse-instance.sh` — helper to reuse or recreate the proxy instance
- `clusters/cloud-proxy/startup-script.sh` — VM startup script

How to run common tasks (local workspace task exists):

```bash
# Run the reuse-instance helper (example)
cd clusters/cloud-proxy && ./reuse-instance.sh
```
