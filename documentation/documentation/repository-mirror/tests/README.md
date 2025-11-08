# tests

Purpose: Lightweight test and verification scripts for common tasks (ingress checks, etc.).

Key files:
- `tests/ingress.sh` — checks HTTPRoutes and ingress functionality.

Notes: These are shell-based checks intended for quick verification. For CI-grade tests, consider adding unit or integration tests that run `kubectl kustomize` and verify rendered manifests.
