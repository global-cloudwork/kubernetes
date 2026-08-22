# Space Age GitOps Bootstrap Implementation

## Overview

This document describes the refactored bootstrap system that implements Space Age GitOps principles using a pure Helm-based approach.

## What Changed

### Old Bootstrap (Kustomize-based)
- Used `kustomize --enable-helm` for inline Helm rendering
- Separate imperative deployment phases (infrastructure, ArgoCD, applications)
- Manual `kubectl create secret` commands for credentials
- ConfigMap patching via imperative kubectl commands
- No idempotency guarantees
- No explicit hydrator configuration

### New Bootstrap (Helm-based)
- Pure Helm chart architecture (`helm/bootstrap/`)
- Single logical deployment with multiple ordered steps
- All configuration declared in YAML templates
- Environment-specific values (dev vs staging)
- Fully idempotent - can rerun anytime safely
- Explicit sourceHydrator spec in Applications
- Better separation of concerns

## Directory Structure

```
helm/bootstrap/
├── Chart.yaml                                    # Helm chart metadata
├── values.yaml                                   # Base configuration (common)
├── values-dev.yaml                               # Dev overrides (ephemeral)
├── values-staging.yaml                           # Staging overrides (persistent)
└── templates/
    ├── namespace.yaml                            # Create argocd, authentik, applications namespaces
    ├── repo-write-secret.yaml                    # Git credentials for Hydrator
    ├── authentik-secret.yaml                     # Authentik secret key
    ├── argocd-hydrator-config.yaml               # Enable Hydrator in ConfigMap
    ├── argocd-app-project.yaml                   # Access control (AppProject)
    └── argocd-initial-applications.yaml          # Core app Application with sourceHydrator
```

## Key Features

### 1. Environment-Specific Configuration

**Dev Environment** (`values-dev.yaml`):
- Ephemeral cluster (destroyed and recreated on bootstrap)
- Sync branches: `environment/dev-next` (render target) → `environment/dev` (sync source)
- Fresh Authentik secret generated each time
- Minimal persistence (10Gi)

**Staging Environment** (`values-staging.yaml`):
- Persistent cluster (always-on)
- Sync branches: `environment/staging-next` (render target) → `environment/staging` (sync source)
- Reused Authentik secret across reboots
- Larger persistence (50Gi) for data retention

### 2. Source Hydrator Integration

The bootstrap enables ArgoCD's Source Hydrator with this configuration:

```yaml
sourceHydrator:
  drySource:
    repoURL: https://github.com/global-cloudwork/kubernetes
    targetRevision: main                          # Source templates branch
    path: helm                                    # Where Helm charts live
    helm:
      releaseName: core-apps

  hydrateTo:
    targetBranch: environment/{dev|staging}-next # Render target branch
    targetPath: rendered

  syncSource:
    targetBranch: environment/{dev|staging}      # Sync source branch
    path: rendered                                # Where rendered manifests are
```

**Flow:**
1. Developer commits changes to `main` branch
2. Hydrator detects change, renders Helm templates
3. Rendered manifests committed to `environment/ENV-next`
4. GitOps Promoter creates PR: `environment/ENV-next` → `environment/ENV`
5. Commit status checks verify policy compliance
6. When gates pass, PR auto-merges
7. ArgoCD syncs from `environment/ENV` to the cluster

### 3. Secret Management

Secrets are declared declaratively in templates, not created imperatuvely:

**Repository Write Secret** (`repo-write-secret.yaml`):
- For Hydrator to write rendered manifests to Git
- Labeled as `argocd.argoproj.io/secret-type: repository-write`
- Injected via `--set repository.username` and `--set repository.password`

**Authentik Secret** (`authentik-secret.yaml`):
- Secret key for Authentik deployment
- Injected via `--set authentik.secretKey`

### 4. Access Control

AppProject (`argocd-app-project.yaml`):
- Defines which repositories and destinations are allowed
- Permits any namespace on the local cluster
- Blocks Namespace resources in kube-system
- Restricts to repo: `https://github.com/global-cloudwork/kubernetes`

## Usage

### Bootstrap Dev Environment

```bash
export GITHUB_USERNAME=your-github-username
export GITHUB_PAT_TOKEN=your-personal-access-token
cd /home/omen/Documents/Development/kubernetes
./scripts/omen/bootstrap.sh dev
```

This will:
1. Destroy any existing Kind cluster
2. Create fresh Kind cluster
3. Deploy infrastructure via kustomize
4. Deploy ArgoCD via kustomize
5. Apply bootstrap Helm configuration
6. Enable Source Hydrator
7. Create initial Applications with sourceHydrator spec

### Bootstrap Staging Environment

```bash
export GITHUB_USERNAME=your-github-username
export GITHUB_PAT_TOKEN=your-personal-access-token
cd /home/omen/Documents/Development/kubernetes
./scripts/omen/bootstrap.sh staging
```

This will:
1. Skip cluster deletion (assumes existing cluster)
2. Re-apply infrastructure (idempotent update)
3. Re-apply ArgoCD configuration
4. Re-apply bootstrap configuration

## Template Rendering

Verify templates render correctly:

```bash
# Dev environment
helm template bootstrap helm/bootstrap \
  -f helm/bootstrap/values-dev.yaml \
  --set authentik.secretKey="$(openssl rand -base64 36)" \
  --set repository.username="$GITHUB_USERNAME" \
  --set repository.password="$GITHUB_PAT_TOKEN" | less

# Staging environment
helm template bootstrap helm/bootstrap \
  -f helm/bootstrap/values-staging.yaml \
  --set authentik.secretKey="your-staging-secret" \
  --set repository.username="$GITHUB_USERNAME" \
  --set repository.password="$GITHUB_PAT_TOKEN" | less
```

## Validation

The bootstrap has been validated to:

- ✓ Render valid YAML for both dev and staging environments
- ✓ Include all required resource kinds (Namespace, Secret, ConfigMap, AppProject, Application)
- ✓ Create 3 namespaces (argocd, authentik, applications)
- ✓ Configure sourceHydrator spec with correct branches
- ✓ Enable hydrator in ConfigMap
- ✓ Label repository secret for ArgoCD recognition
- ✓ Use environment-specific branch configurations

## Important Constraints

1. **syncSource.path must not be root**: Cannot be empty, ".", or "/"
   - Must be `rendered` or another subdirectory

2. **Deterministic rendering**: No timestamps, random UUIDs, or dynamic data
   - Manifests must render identically every time

3. **Single hydrator per branch**: Each Application needs unique target branches
   - Don't have multiple Applications writing to same branch

4. **Git notes used for state**: Hydrator uses git notes internally
   - Don't delete git notes

## Next Steps

After bootstrap completes:

1. **Verify hydration**: Commit change to `main`, watch for rendering to `environment/ENV-next`
2. **Test promotion**: Create PR from `environment/ENV-next` → `environment/ENV`
3. **Check gates**: Verify commit status checks run and pass
4. **Confirm sync**: Watch ArgoCD sync from `environment/ENV` to cluster

## Troubleshooting

**sourceHydrator not recognized**
- Ensure ArgoCD version 3.2+
- Check hydrator.enabled is "true" in ConfigMap
- Verify Application resource has sourceHydrator spec

**Hydrator not rendering**
- Check Hydrator controller logs: `kubectl logs -n argocd deployment/argocd-controller-manager`
- Verify git credentials are correct: `kubectl get secret -n argocd global-cloudwork-kubernetes-write -o yaml`
- Check that drySource.path exists in main branch

**Application not syncing**
- Verify syncSource.targetBranch exists in Git
- Check Application logs: `kubectl describe application -n argocd`
- Confirm syncSource.path contains rendered manifests

## References

- ArgoCD Source Hydrator: https://argo-cd.readthedocs.io/en/stable/
- GitOps Promoter: https://github.com/argoproj-labs/gitops-promoter
- Helm Chart Development: https://helm.sh/docs/chart_template_guide/
