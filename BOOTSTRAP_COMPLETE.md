# Complete System Bootstrap Guide

**Date**: August 21, 2026
**Status**: Full declarative bootstrap system implemented
**Location**: All in `/kubernetes/core/` and `/scripts/omen/`

---

## Overview

The kubernetes cluster bootstrap has been fully implemented with:
- ✅ Declarative Core Infrastructure (CRDs, namespaces, applications)
- ✅ Automatic Manifest Rendering (Source Hydrator applications)
- ✅ Environment Promotion Pipeline (development → testing → production)
- ✅ Bootstrap Scripts (automated setup)
- ✅ Complete Documentation

---

## Bootstrap Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  BOOTSTRAP FLOW                                                 │
└─────────────────────────────────────────────────────────────────┘

1. kind-reboot.sh
   ├─ Delete and recreate cluster
   ├─ Install CRDs (ArgoCD, Cert-Manager, Gateway API)
   ├─ Create namespaces
   ├─ Deploy ArgoCD (via kustomize)
   └─ Deploy initial ArgoCD configuration

2. bootstrap-hydrator.sh  [MANUAL - requires GitHub PAT]
   ├─ Enable Source Hydrator in ArgoCD ConfigMap
   ├─ Create repository write secret
   ├─ Deploy Hydrator Applications (21 total)
   └─ Deploy Environment Applications (21 total)

3. Automatic (via hydrator)
   ├─ Source Hydrator detects changes to helm charts
   ├─ Renders manifests using helm template
   ├─ Commits rendered output to next-* branches
   ├─ Environment Applications sync from rendered output
   └─ Deployments update automatically
```

---

## Files Organized for Bootstrap

### Kubernetes Core Infrastructure
```
kubernetes/
├── kustomization.yaml              # Base bootstrap (CRDs, namespaces)
├── kustomization-hydrator.yaml     # Hydrator configuration (Phase 2)
├── namespace.yaml                  # Kubernetes namespaces
└── core/
    ├── application-set.yaml        # Deprecated (will be removed)
    ├── app-project.yaml            # ArgoCD project
    ├── gateway.yaml                # Gateway API
    ├── gateway-class.yaml          # Gateway class
    ├── hydrator-applications.yaml  # ✨ Source Hydrator (21 apps)
    ├── development.yaml            # Environment Applications (7)
    ├── testing.yaml                # Environment Applications (7)
    ├── prod.yaml                   # Environment Applications (7)
    └── hydrator-secret.yaml.example # Template for write secret
```

### Bootstrap Scripts
```
scripts/omen/
├── kind-reboot.sh                  # Phase 1: Cluster bootstrap
├── bootstrap-hydrator.sh           # Phase 2: Hydrator setup
└── kind-config.yaml                # Kind cluster configuration
```

---

## Phase 1: Cluster Bootstrap (Automated)

### What kind-reboot.sh Does

1. **Delete existing cluster**
   ```bash
   kind delete cluster
   ```

2. **Create new cluster**
   ```bash
   kind create cluster --config scripts/omen/kind-config.yaml
   ```

3. **Wait for readiness**
   ```bash
   sleep 60
   ```

4. **Install CRDs and infrastructure**
   ```bash
   kubectl kustomize --enable-helm kubernetes | kubectl apply --server-side
   ```

5. **Create secrets**
   ```bash
   kubectl create secret generic authentik-secret-key --from-literal=...
   ```

6. **Deploy ArgoCD**
   ```bash
   kubectl kustomize --enable-helm applications/argocd | kubectl apply --server-side
   ```

### How to Run

```bash
./scripts/omen/kind-reboot.sh
```

### Expected Output

```
Section: Deploy Base and Core, then restart RKE2
Cluster created successfully
CRDs installed
namespaces: argocd, authentik, cert-manager, gateway, etc.
ArgoCD deployed
```

**Timing**: ~5-10 minutes

---

## Phase 2: Hydrator Bootstrap (Semi-Automated)

### Prerequisites

1. **GitHub Personal Access Token (PAT)**
   - Go to https://github.com/settings/tokens
   - Create "Personal access token (classic)"
   - Select "repo" scope
   - Copy token (you won't see it again)

2. **ArgoCD installed and running**
   - Verify: `kubectl get deployment -n argocd argocd-application-controller`

3. **ArgoCD version 3.2+**
   - Verify: `kubectl get deployment -n argocd argocd-application-controller -o yaml | grep image`

### How to Run

```bash
./scripts/omen/bootstrap-hydrator.sh <github-username> <github-pat-token>

# Example:
./scripts/omen/bootstrap-hydrator.sh myuser ghp_xxxxxxxxxxxx
```

### What bootstrap-hydrator.sh Does

1. **Verifies prerequisites**
   - kubectl available
   - ArgoCD namespace exists
   - ArgoCD version compatible

2. **Enables Source Hydrator**
   - Patches `argocd-cmd-params-cm` ConfigMap
   - Sets `hydrator.enabled: "true"`
   - Sets `commit.server: "argocd-commit-server:8086"`

3. **Creates repository write secret**
   - Name: `global-cloudwork-kubernetes-write`
   - Type: repository-write (labeled for hydrator)
   - Contains GitHub credentials

4. **Deploys Hydrator Applications**
   - 21 total (7 apps × 3 environments)
   - Each configured to render from main → next-* branches

5. **Deploys Environment Applications**
   - 21 total (7 apps × 3 environments)
   - Each configured to sync from environment branches

6. **Verifies deployment**
   - Checks secret creation
   - Confirms applications deployed
   - Provides next steps

### Expected Output

```
ArgoCD Source Hydrator Bootstrap
▶ Step 1: Verifying prerequisites...
✓ kubectl found
✓ ArgoCD namespace found
✓ ArgoCD version: v3.2.0

▶ Step 2: Enabling Source Hydrator in ArgoCD...
✓ Source Hydrator enabled in ArgoCD ConfigMap

▶ Step 3: Creating repository write secret...
✓ Repository write secret created and labeled

▶ Step 4: Verifying secret configuration...
✓ Secret verified
✓ Secret label corrected

▶ Step 5: Deploying Hydrator Applications...
✓ Hydrator Applications deployed

▶ Step 6: Deploying Environment Applications...
✓ Environment Applications deployed

▶ Step 7: Waiting for ArgoCD to reconcile...

▶ Verification...
✓ Hydrator Applications deployed: ~21
✓ Environment Applications deployed: dev(7) testing(7) prod(7)

✓ ArgoCD Source Hydrator bootstrap complete!
```

**Timing**: ~2-5 minutes

---

## Phase 3: Automated Hydration (After Bootstrap)

### What Happens Automatically

1. **Hydrator detects change on main branch**
   - Developer modifies helm chart in `/helm/[app]/values-dev.yaml`
   - Commits to main branch
   - Pushes to origin/main

2. **Source Hydrator renders manifests**
   - ArgoCD Application Controller detects change
   - Hydrator runs `helm template` with appropriate values
   - Renders full Kubernetes manifests
   - (5-30 seconds)

3. **Hydrator commits rendered output**
   - Creates commit with rendered manifests
   - Pushes to `next-development` branch
   - (5-10 seconds)

4. **Developer reviews and promotes**
   - Reviews rendered manifests in git
   - Merges `next-development` → `development` (via PR)
   - Creates commit history for audit

5. **Environment Application syncs**
   - ArgoCD Application watching `development` branch
   - Detects commit on development branch
   - Syncs Application from `helm/[app]-hydrated/`
   - Deploys to development cluster
   - (5-15 seconds)

**Total Time**: Main → Deployed: ~60 seconds

---

## Declarative Files Breakdown

### hydrator-applications.yaml (21 Applications)

**Purpose**: Automatically render manifests from main to environment branches

**Structure**: 
- 7 apps (traefik, argocd, cert-manager, authentik, n8n, neo4j, homepage)
- 3 environments (dev, testing, prod)
- Total: 21 SourceHydrator Applications

**Each Application**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hydrator-{app}-{env}
spec:
  source:
    path: helm/{app}
    helm:
      valuesFiles:
        - values.yaml
        - values-{env}.yaml
  sourceHydrator:
    hydrateTo:
      targetBranch: next-{env}       # Where to commit rendered manifests
    syncSource:
      targetBranch: {env}             # Where environment apps sync from
      path: helm/{app}-hydrated
```

### development.yaml / testing.yaml / prod.yaml (21 Applications)

**Purpose**: Sync rendered manifests from environment branches

**Structure**: 
- 7 apps per file
- Each references hydrated manifests
- Configured for appropriate sync policy

**Sync Policy**:
- Development: auto-sync (prune + selfHeal)
- Testing: auto-sync
- Production: manual sync (safety)

### hydrator-secret.yaml.example

**Purpose**: Template for repository write secret

**Why Template?**: 
- Should NOT be committed to git with real credentials
- Created separately with actual GitHub PAT
- Only exists in cluster, not in repository

**How to Create**:
```bash
# Option 1: Use bootstrap-hydrator.sh (recommended)
./scripts/omen/bootstrap-hydrator.sh username pat_token

# Option 2: Manual creation
kubectl create secret generic global-cloudwork-kubernetes-write \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/global-cloudwork/kubernetes \
  --from-literal=username=myuser \
  --from-literal=password=ghp_mytoken

kubectl label secret global-cloudwork-kubernetes-write \
  -n argocd \
  argocd.argoproj.io/secret-type=repository-write
```

---

## Bootstrap Checklist

### Phase 1: Cluster Bootstrap
- [ ] Run `./scripts/omen/kind-reboot.sh`
- [ ] Wait for script to complete (~5-10 minutes)
- [ ] Verify: `kubectl get deployment -n argocd argocd-application-controller`
- [ ] Access ArgoCD: `kubectl port-forward -n argocd svc/argocd-server 8080:443`

### Phase 2: Hydrator Bootstrap
- [ ] Create GitHub Personal Access Token
- [ ] Run `./scripts/omen/bootstrap-hydrator.sh username token`
- [ ] Wait for script to complete (~2-5 minutes)
- [ ] Verify: `kubectl get application -n argocd | grep hydrator`

### Phase 3: Verify Hydration
- [ ] Monitor hydrator: `kubectl logs -n argocd deployment/argocd-application-controller -f | grep -i hydrat`
- [ ] Check branches: `git fetch origin && git branch -r | grep next-`
- [ ] Inspect rendered: `git show origin/next-development:helm/traefik-hydrated/`
- [ ] Test promotion: Merge `next-development` → `development`
- [ ] Monitor sync: `kubectl get application -n argocd -w`

---

## Troubleshooting

### Bootstrap Fails at CRD Installation

**Error**: `failed to install CRD`

**Solution**:
1. Check network connectivity
2. Verify remote URLs are accessible
3. Retry with: `kubectl kustomize --enable-helm kubernetes | kubectl apply --server-side --force-conflicts -f -`

### Hydrator Bootstrap Script Fails

**Error**: `Failed to patch argocd-cmd-params-cm`

**Solution**:
1. Verify ArgoCD is fully deployed: `kubectl get pod -n argocd`
2. Check ConfigMap exists: `kubectl get configmap -n argocd argocd-cmd-params-cm`
3. Manually enable: `kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"hydrator.enabled":"true"}}'`

### Source Hydrator Not Creating Commits

**Error**: No commits on `next-*` branches

**Solution**:
1. Verify hydrator enabled: `kubectl get configmap -n argocd argocd-cmd-params-cm -o yaml | grep hydrator`
2. Check write secret: `kubectl get secret -n argocd global-cloudwork-kubernetes-write`
3. Verify secret label: `kubectl get secret -n argocd -L argocd.argoproj.io/secret-type`
4. Check logs: `kubectl logs -n argocd deployment/argocd-application-controller | grep -i "hydrat\|error"`

### Applications Not Syncing

**Error**: Application status shows "OutOfSync" or stuck

**Solution**:
1. Check Application spec: `kubectl get application traefik-dev -o yaml`
2. Verify branch exists: `git branch -r | grep development`
3. Check path exists: `git ls-tree origin/development helm/`
4. Manually sync: `argocd app sync traefik-dev` (if CLI available)

---

## Maintenance

### Adding New Applications

1. Create helm chart in `helm/[new-app]/`
2. Update `hydrator-applications.yaml` with 3 new entries (dev, testing, prod)
3. Update `development.yaml`, `testing.yaml`, `prod.yaml` with new Application
4. Push changes to main
5. Hydrator will automatically render and deploy

### Updating Helm Charts

1. Modify `helm/[app]/values.yaml` or environment overrides
2. Commit to main branch
3. Hydrator will automatically render within 30 seconds
4. Review rendered manifests in `next-*` branch
5. Promote through environments as needed

### Scaling Down Bootstrap

To deploy without hydrator (for testing):

```bash
# Phase 1 only
./scripts/omen/kind-reboot.sh

# This deploys core infrastructure without hydrator
# Applications must be deployed manually or via other means
```

---

## Complete Bootstrap Command Sequence

```bash
# Phase 1: Bootstrap cluster
./scripts/omen/kind-reboot.sh

# Wait for ArgoCD to be ready (~2 minutes)
kubectl wait deployment -n argocd argocd-application-controller --for condition=available --timeout=300s

# Phase 2: Bootstrap hydrator (requires GitHub PAT)
./scripts/omen/bootstrap-hydrator.sh <username> <pat-token>

# Verify complete setup
kubectl get application -n argocd -o wide

# Monitor hydration
kubectl logs -n argocd deployment/argocd-application-controller -f

# Test promotion workflow
git fetch origin
git log origin/next-development --oneline
```

**Total Time**: ~20 minutes (including waiting)

---

## Files Summary

| File | Purpose | Type | Location |
|------|---------|------|----------|
| kind-reboot.sh | Cluster bootstrap | Script | scripts/omen/ |
| bootstrap-hydrator.sh | Hydrator setup | Script | scripts/omen/ |
| kind-config.yaml | Cluster config | Config | scripts/omen/ |
| kustomization.yaml | Base bootstrap | Kustomize | kubernetes/ |
| kustomization-hydrator.yaml | Hydrator config | Kustomize | kubernetes/ |
| hydrator-applications.yaml | Hydrator apps (21) | Manifests | kubernetes/core/ |
| development.yaml | Dev apps (7) | Manifests | kubernetes/core/ |
| testing.yaml | Test apps (7) | Manifests | kubernetes/core/ |
| prod.yaml | Prod apps (7) | Manifests | kubernetes/core/ |
| hydrator-secret.yaml.example | Write secret template | Template | kubernetes/core/ |

---

**Status**: ✅ Complete declarative bootstrap system ready
**Next Step**: Run `./scripts/omen/kind-reboot.sh` to bootstrap cluster
**Then**: Run `./scripts/omen/bootstrap-hydrator.sh` to enable hydrator

---

*System bootstrap documentation*
*August 21, 2026*
