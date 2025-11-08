# Repository mirror (directory-only)

This directory mirrors the repository's folder structure. It contains one markdown file per folder that documents the purpose of that folder and points to the most relevant files to review.

Rules for the mirror:
- Mirror the directory path, not file contents. Put a single markdown file per folder named `<folder>.md` or `README.md`.
- Keep entries short: purpose (1-2 lines), key files (list), and quick pointers (how to render/apply or where to look next).
- Update when you add/rename a folder in the repo.

Example: to find documentation for `applications/open-webui/httproute.yaml` open `obsidian/documentation/repository-mirror/applications/open-webui.md` which describes the app and where to look next.

Note: application docs are stored as flat files under `.../applications/<app>.md` (not nested directories). This keeps the mirror easy to scan.
