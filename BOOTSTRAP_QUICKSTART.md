# Bootstrap Quick Start Guide

## Prerequisites

- GitHub username and Personal Access Token (PAT) with repo access
- `kind` installed (for dev environment)
- `kubectl` configured
- `helm` installed

## Quick Bootstrap

### 1. Set Environment Variables

```bash
export GITHUB_USERNAME="your-github-username"
export GITHUB_PAT_TOKEN="your-github-pat"
```

### 2. Bootstrap Dev (Ephemeral)

```bash
cd /home/omen/Documents/Development/kubernetes
./scripts/omen/bootstrap.sh dev
```

This destroys and recreates the cluster from scratch. Takes ~5-10 minutes.

### 3. Bootstrap Staging (Persistent)

```bash
./scripts/omen/bootstrap.sh staging
```

This updates the staging cluster in-place. Takes ~3-5 minutes.

## What Gets Deployed

After bootstrap completes:

1. **Namespaces**
   - `argocd` - ArgoCD components
   - `authentik` - Authentik services
   - `applications` - Deployed applications

2. **Secrets**
   - `authentik-secret-key` - in `authentik` namespace
   - `global-cloudwork-kubernetes-write` - in `argocd` namespace (for Hydrator)

3. **ConfigMap**
   - `argocd-cmd-params-cm` - Enables Hydrator

4. **Access Control**
   - `AppProject: core-apps` - Defines what ArgoCD can deploy

5. **Applications**
   - `Application: core-apps-hydrator` - Watches source, renders, syncs

## Access ArgoCD

After bootstrap, access ArgoCD UI at: **http://argocd.local/**

To get admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

## How Space Age GitOps Works

```
You commit to main
        ↓
Hydrator renders templates
        ↓
Rendered manifests pushed to environment/ENV-next
        ↓
GitOps Promoter creates PR: environment/ENV-next → environment/ENV
        ↓
Tests & gates run
        ↓
When all pass, PR auto-merges to environment/ENV
        ↓
ArgoCD syncs from environment/ENV to your cluster
```

## Environment Branches

| Branch | Purpose | Who edits? |
|--------|---------|-----------|
| `main` | Source templates (Helm) | You (developers) |
| `environment/dev-next` | Hydrator staging for dev | Hydrator (auto) |
| `environment/dev` | Active sync source for dev | Promoter (auto) |
| `environment/staging-next` | Hydrator staging for staging | Hydrator (auto) |
| `environment/staging` | Active sync source for staging | Promoter (auto) |

## Making Changes

1. **Edit Helm templates** in `helm/` directory in `main` branch
2. **Commit to `main`**
3. **Hydrator automatically renders** templates to `environment/ENV-next`
4. **GitOps Promoter creates PR** from `-next` to active branch
5. **Tests run** via commit status checks
6. **PR auto-merges** when gates pass
7. **ArgoCD syncs** to the cluster

## Verify Hydrator is Working

Check if Hydrator has rendered to the `-next` branch:

```bash
# For dev
git log environment/dev-next --oneline | head -5

# For staging
git log environment/staging-next --oneline | head -5
```

You should see commits from "argocd-hydrator" user.

## Check ArgoCD Application Status

```bash
# List applications
kubectl get applications -n argocd

# Check specific application
kubectl describe application core-apps-hydrator -n argocd

# Watch sync status
kubectl get applications -n argocd -w
```

## Troubleshoot

### Bootstrap fails during infrastructure deployment
```bash
# Check what's deployed
kubectl get namespace
kubectl get pods -A

# Check for errors
kubectl logs -n argocd -l app.kubernetes.io/name=bootstrap
```

### Hydrator not rendering
```bash
# Check hydrator controller logs
kubectl logs -n argocd deployment/argocd-controller-manager | grep -i hydrator

# Verify git credentials
kubectl get secret -n argocd global-cloudwork-kubernetes-write -o yaml

# Check Application resource
kubectl get application core-apps-hydrator -n argocd -o yaml
```

### ArgoCD not syncing
```bash
# Check Application status
kubectl describe application core-apps-hydrator -n argocd

# Check if sync branch exists
git branch -a | grep environment/

# Verify rendered manifests exist
git ls-tree environment/dev rendered
```

## Rerun Bootstrap

Bootstrap is fully idempotent - you can rerun it anytime:

```bash
# For dev: destroys and recreates cluster
./scripts/omen/bootstrap.sh dev

# For staging: updates in place
./scripts/omen/bootstrap.sh staging
```

## Next: Deploy Applications

After bootstrap, add applications by creating Helm charts in `helm/` and commits to `main`. The Hydrator will automatically render them to the environment branches.

Example structure:
```
helm/
├── bootstrap/        # Bootstrap configuration
├── my-app/           # Application Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── another-app/
```

Commit to `main`, let Hydrator render, watch it deploy via ArgoCD!

## Questions?

See [BOOTSTRAP_IMPLEMENTATION.md](BOOTSTRAP_IMPLEMENTATION.md) for detailed documentation.
