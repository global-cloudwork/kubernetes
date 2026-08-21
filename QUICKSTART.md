# Space Age GitOps - Quick Start Guide

**TL;DR**: Complete Space Age GitOps with automatic manifest rendering and multi-environment promotion.

---

## 5-Minute Setup

### Prerequisites
- Kind cluster (or existing Kubernetes)
- ArgoCD 3.2+ (auto-installed)
- GitHub Personal Access Token (create at github.com/settings/tokens)

### Step 1: Bootstrap Cluster (5-10 minutes)

```bash
./scripts/omen/kind-reboot.sh
```

**What it does**:
- Creates Kind cluster
- Installs CRDs (ArgoCD, Cert-Manager, Gateway API)
- Deploys ArgoCD
- Configures namespaces and gateways

### Step 2: Enable Hydrator (2-5 minutes)

```bash
./scripts/omen/bootstrap-hydrator.sh <github-username> <github-pat-token>

# Example:
./scripts/omen/bootstrap-hydrator.sh alice ghp_xxxxxxxxxxxx
```

**What it does**:
- Enables Source Hydrator in ArgoCD
- Creates repository write secret
- Deploys 21 Hydrator Applications (auto-render manifests)
- Deploys 21 Environment Applications (sync from branches)

### Step 3: Verify Setup

```bash
# Check applications deployed
kubectl get application -n argocd

# Monitor hydration
kubectl logs -n argocd deployment/argocd-application-controller -f

# Check rendered manifests
git fetch origin
git log origin/next-development --oneline
```

**Total Time**: ~20 minutes

---

## How It Works

```
┌─────────────────┐
│  helm/traefik/  │ (main branch)
│  values.yaml    │
│  values-dev.yaml│
└────────┬────────┘
         │
         ▼ (Source Hydrator)
┌──────────────────────┐
│ next-development     │ (rendered manifests)
│ helm/traefik-        │
│ hydrated/manifests   │
└────────┬─────────────┘
         │ (Developer merges PR)
         ▼
┌──────────────────────┐
│ development branch   │
│ helm/traefik-        │
│ hydrated/manifests   │
└────────┬─────────────┘
         │ (Application syncs)
         ▼
    📦 DEPLOYED 📦
```

---

## Common Tasks

### Modify Configuration

```bash
# Edit values for development environment
vi helm/traefik/values-dev.yaml

# Commit and push
git add helm/traefik/values-dev.yaml
git commit -m "config: update traefik replicas for dev"
git push origin main

# Hydrator automatically renders within 30 seconds
# Check progress: git log origin/next-development --oneline
```

### Promote to Next Environment

```bash
# After validating in development, promote to staging/testing
git checkout testing
git merge next-testing
git push origin testing

# Application syncs automatically
kubectl get application traefik-testing -o wide
```

### Monitor Deployments

```bash
# Watch all applications
kubectl get application -n argocd -w

# Check specific app
kubectl get application traefik-dev -o yaml

# View sync status
argocd app get traefik-dev  # (if CLI available)
```

### Rollback Deployment

```bash
# Find bad commit on environment branch
git log development --oneline

# Revert the commit
git revert <commit-hash>
git push origin development

# Application automatically syncs to previous state
```

---

## Architecture at a Glance

| Component | Purpose | Location |
|-----------|---------|----------|
| **Helm Charts** | DRY source templates | `helm/[app]/` |
| **Values Files** | Environment config | `helm/[app]/values-*.yaml` |
| **Hydrator Apps** | Auto-render manifests | `kubernetes/core/hydrator-applications.yaml` |
| **Environment Apps** | Sync rendered output | `kubernetes/core/{development,testing,prod}.yaml` |
| **Rendered Output** | Committed manifests | `origin/next-*` and `origin/*` branches |

**Flow**: `helm/` → Hydrator → `next-*` branch → Environment App → Cluster

---

## Troubleshooting

### Hydrator Not Creating Commits

```bash
# Check if hydrator is enabled
kubectl get configmap -n argocd argocd-cmd-params-cm -o yaml | grep hydrator

# Check if write secret exists
kubectl get secret -n argocd global-cloudwork-kubernetes-write

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller | grep -i hydrat
```

### Application Not Syncing

```bash
# Check Application spec
kubectl get application traefik-dev -o yaml

# Check if branch exists
git branch -r | grep development

# Check if path exists
git ls-tree origin/development helm/
```

### Make Manual Secret

```bash
kubectl create secret generic global-cloudwork-kubernetes-write \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/global-cloudwork/kubernetes \
  --from-literal=username=<your-username> \
  --from-literal=password=<your-pat-token>

kubectl label secret global-cloudwork-kubernetes-write \
  -n argocd \
  argocd.argoproj.io/secret-type=repository-write
```

---

## Environment Structure

### Development (development branch)
- Auto-sync enabled
- Fast iteration
- Lower resource requirements
- All 7 applications deployed

### Testing/Staging (testing branch)
- Auto-sync enabled
- Validation environment
- Near-production config
- All 7 applications deployed

### Production (live-production branch)
- Manual sync (requires approval)
- Safety gate before deployment
- Resource-heavy config
- All 7 applications deployed

---

## File Organization

```
kubernetes/
├── kustomization.yaml              # Phase 1: Base bootstrap
├── kustomization-hydrator.yaml     # Phase 2: Hydrator setup
└── core/
    ├── hydrator-applications.yaml  # ← Hydrator config
    ├── development.yaml            # ← Environment apps
    ├── testing.yaml
    └── prod.yaml

helm/
├── traefik/
├── argocd/
├── cert-manager/
├── authentik/
├── n8n/
├── neo4j/
└── homepage/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-testing.yaml
    ├── values-prod.yaml
    └── templates/

scripts/omen/
├── kind-reboot.sh                  # ← Phase 1: Run first
├── bootstrap-hydrator.sh           # ← Phase 2: Run second
└── kind-config.yaml
```

---

## Detailed Docs

- **BOOTSTRAP_COMPLETE.md** - Full bootstrap documentation (450+ lines)
- **PHASE_2_SETUP_GUIDE.md** - Detailed hydrator setup guide (409 lines)
- **SPACE_AGE_GITOPS_SETUP.md** - Overview and configuration details
- **IMPLEMENTATION_COMPLETE.md** - Complete implementation reference

---

## Key Features

✅ **Automated Rendering** - Helm templates rendered automatically
✅ **Full Audit Trail** - All changes visible in git history
✅ **Environment Separation** - Different config per environment
✅ **Promotion Gates** - Manual approval for production
✅ **GitOps Native** - Uses git branches, no new tools
✅ **Deterministic** - Same source always produces same output
✅ **Reversible** - Rollback any deployment by reverting git commit
✅ **Scalable** - Easy to add new applications or environments

---

## Support

**Questions?** Check the docs:
1. **Setup issues**: → BOOTSTRAP_COMPLETE.md
2. **Hydrator config**: → PHASE_2_SETUP_GUIDE.md
3. **Daily operations**: → QUICKSTART.md (this file)
4. **Architecture**: → SPACE_AGE_GITOPS_SETUP.md

**Bootstrap scripts**:
- `./scripts/omen/kind-reboot.sh` - Cluster setup
- `./scripts/omen/bootstrap-hydrator.sh` - Hydrator setup

---

**Ready?** Start with: `./scripts/omen/kind-reboot.sh`

*Space Age GitOps - August 2026*
