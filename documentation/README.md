# Obsidian notes and repository mirror

This folder contains project-specific notes and a directory-only mirror of the repository used for documentation and quick discovery.

Quick pointers:
- `obsidian/documentation/repository-mirror/` — mirrors the repository directory structure and contains one markdown file per folder describing intent, important files and where to look in the code.
- Top-level notes (e.g. `Cilium System Requirements.md`, `Cloud-Proxy.md`) hold operational guidance and design decisions.

Guidance for contributors:
- When you add or rename a folder in the repo, add or update the corresponding file under `obsidian/documentation/repository-mirror/<path>/` so readers can find documentation by path.
- Keep notes concise and link to manifests in `applications/` or `base/` when relevant.

This folder is intended to be read-only from automation POV — maintain it by hand when structural changes occur.
