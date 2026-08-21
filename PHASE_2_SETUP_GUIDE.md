# Phase 2: ArgoCD Source Hydrator Setup Guide

## Overview

Phase 1 (Completed ✅): Migrated all applications to helm charts with environment-specific values.

Phase 2 (This Guide): Configure ArgoCD Source Hydrator to automatically render manifests from main branch to environment branches.

Phase 3 (Future): Remove old ApplicationSet and kustomization files after validation.

---

## Prerequisites

- ArgoCD version 3.2+ installed
- GitHub Personal Access Token (PAT) with `repo` write permissions
- Access to ArgoCD CLI or kubectl with ArgoCD namespace access
- The main branch with new helm charts (already pushed)

---

## Step 1: Prepare GitHub PAT

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Create new token with scopes:
   - `repo` (full control of private repositories)
   - `workflow` (optional, for CI/CD)
3. Copy the token - you'll need it in the next step

**Token Name Suggestion**: `argocd-hydrator-write`

---

## Step 2: Create Repository Write Secret in ArgoCD

This secret allows ArgoCD's hydrator to push rendered manifests to the repository.

```bash
kubectl create secret generic global-cloudwork-kubernetes-write \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/global-cloudwork/kubernetes \
  --from-literal=username=your-github-username \
  --from-literal=password=your-github-pat

# Add the label to mark it as a write secret
kubectl label secret global-cloudwork-kubernetes-write \
  -n argocd \
  argocd.argoproj.io/secret-type=repository-write
```

**Verify:**
```bash
kubectl get secret -n argocd global-cloudwork-kubernetes-write -o yaml
```

---

## Step 3: Enable Source Hydrator in ArgoCD

Update ArgoCD ConfigMap to enable the hydrator:

```bash
kubectl patch configmap argocd-cmd-params-cm -n argocd -p '{
  "data": {
    "hydrator.enabled": "true",
    "commit.server": "argocd-commit-server:8086"
  }
}'
```

**Verify:**
```bash
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep -A2 hydrator
```

Expected output:
```yaml
  hydrator.enabled: "true"
  commit.server: "argocd-commit-server:8086"
```

---

## Step 4: Create ApplicationSet for Hydration

The hydrator needs Applications to watch. Create an ApplicationSet that generates Applications for each environment using the helm charts.

Save this file and apply it:

```bash
cat > hydrator-applications.yaml << 'EOF'
---
# Development Hydrator Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik-hydrator-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/global-cloudwork/kubernetes
    targetRevision: HEAD
    path: helm/traefik
    helm:
      releaseName: traefik
      valuesFiles:
        - values.yaml
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
  sourceHydrator:
    hydrateTo:
      targetBranch: next-development
    syncSource:
      targetBranch: development
      path: helm/traefik-hydrated

---
# Similar applications for other apps...
# (Generate one for each app: argocd, cert-manager, authentik, n8n, neo4j, homepage)
EOF

kubectl apply -f hydrator-applications.yaml
```

---

## Step 5: Full Hydrator Configuration (Automated)

For all 7 applications, here's a script to generate and deploy hydrator applications:

```bash
#!/bin/bash

APPS=("traefik" "argocd" "cert-manager" "authentik" "n8n" "neo4j" "homepage")
REPO="https://github.com/global-cloudwork/kubernetes"

for app in "${APPS[@]}"; do
  for env in dev:development testing:testing prod:live-production; do
    IFS=: read -r short long <<< "$env"
    next="next-$long"
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${app}-hydrator-${short}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO}
    targetRevision: HEAD
    path: helm/${app}
    helm:
      releaseName: ${app}
      valuesFiles:
        - values.yaml
        - values-${short}.yaml
  destination:
    server: https://kubernetes.default.svc
  sourceHydrator:
    hydrateTo:
      targetBranch: ${next}
    syncSource:
      targetBranch: ${long}
      path: helm/${app}-hydrated
  syncPolicy:
    syncOptions:
      - PrunePropagationPolicy=foreground
      - PruneLast=true
EOF
  done
done
```

---

## Step 6: Verify Hydration is Working

1. **Check ArgoCD logs for hydrator activity**:
   ```bash
   kubectl logs -n argocd deployment/argocd-application-controller -f | grep -i hydrat
   ```

2. **Verify commits were pushed to next-* branches**:
   ```bash
   git fetch origin
   git log origin/next-development --oneline | head -5
   git show origin/next-development:helm/traefik-hydrated/Chart.yaml | head -10
   ```

3. **Check Application status**:
   ```bash
   kubectl get application -n argocd | grep hydrator
   ```

---

## Step 7: Deploy Environment Applications

Once hydration is verified and working, deploy the environment-specific applications:

```bash
# Development environment
kubectl apply -f applications/development.yaml

# Testing/Staging environment
kubectl apply -f applications/testing.yaml

# Production environment
kubectl apply -f applications/prod.yaml
```

Verify they're syncing:
```bash
kubectl get application -n argocd -o wide | grep -E "dev|testing|prod"
```

---

## Step 8: Test the Full Promotion Flow

### Manual Test: Make a Change and Promote

1. **Modify a helm chart on main**:
   ```bash
   # Make a small change to test
   echo "  # Test comment $(date)" >> helm/traefik/values-dev.yaml
   git add helm/traefik/values-dev.yaml
   git commit -m "test: verify hydration workflow"
   git push origin main
   ```

2. **Wait for hydrator (5-30 seconds)**:
   ```bash
   sleep 10
   git fetch origin
   git log origin/next-development --oneline | head -3
   ```

3. **Verify rendered manifests**:
   ```bash
   git show origin/next-development:helm/traefik-hydrated/Chart.yaml
   git show origin/next-development:helm/traefik-hydrated/values.yaml
   ```

4. **Promote to development**:
   ```bash
   git checkout development
   git merge next-development
   git push origin development
   ```

5. **Monitor Application sync**:
   ```bash
   watch kubectl get application traefik-dev -o wide
   ```

---

## Troubleshooting

### Issue: Hydrator not creating commits

**Check hydrator is enabled:**
```bash
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep hydrator
```

**Check write secret exists:**
```bash
kubectl get secret -n argocd global-cloudwork-kubernetes-write
```

**Check secret has correct label:**
```bash
kubectl get secret -n argocd -L argocd.argoproj.io/secret-type | grep write
```

**Check Application is deployed:**
```bash
kubectl get application -n argocd | grep hydrator
```

**Check logs:**
```bash
kubectl logs -n argocd deployment/argocd-application-controller | tail -100 | grep -i "hydrat\|error"
kubectl logs -n argocd deployment/argocd-server | tail -100 | grep -i "error"
```

### Issue: Commits failing with permission error

**Verify PAT permissions:**
- Token must have `repo` scope
- Token must not be expired
- GitHub user must have write access to the repository

**Test git push manually:**
```bash
git remote add test https://<YOUR-PAT>@github.com/global-cloudwork/kubernetes.git
git push test main
```

### Issue: Application not syncing after promotion

**Check Application spec:**
```bash
kubectl get application traefik-dev -o yaml | grep -A20 "^spec:"
```

**Verify branch exists:**
```bash
git ls-remote origin | grep "development\|refs/heads/development"
```

**Verify path exists on branch:**
```bash
git ls-tree origin/development | grep helm
git ls-tree origin/development:helm | grep traefik-hydrated
```

---

## Next Steps After Verification

Once the full promotion flow is tested and working:

1. **Delete old kustomization files** (keep as backup first):
   ```bash
   # Backup first
   git checkout -b backup/old-kustomize-files
   git rm applications/*/kustomization.yaml
   git commit -m "backup: save old kustomization files"
   git push origin backup/old-kustomize-files
   
   # Then delete on main
   git checkout main
   git rm applications/*/kustomization.yaml
   git commit -m "refactor: remove old kustomization files"
   ```

2. **Remove old ApplicationSet**:
   ```bash
   git rm kubernetes/core/application-set.yaml
   git commit -m "refactor: remove deprecated ApplicationSet"
   ```

3. **Update AGENTS.md** with new deployment procedures

4. **Archive this guide** in project documentation

---

## Full Hydration + Promotion Workflow

After setup is complete, the workflow becomes:

```
Developer makes change on main
         ↓
helm chart updated (main branch)
         ↓
Source Hydrator detects change (10-30 seconds)
         ↓
Hydrator renders manifests using helm
         ↓
Hydrator commits rendered manifests to next-development
         ↓
Developer reviews rendered output in PR
         ↓
Developer merges PR: next-development → development
         ↓
ArgoCD Application (traefik-dev) syncs from development
         ↓
New version deployed to development cluster
         ↓
After validation, developer manually promotes to testing
         ↓
Hydrator commits to next-testing
         ↓
Developer merges: next-testing → testing
         ↓
ArgoCD syncs to testing cluster
         ↓
After testing passes, promote to live-production
         ↓
Hydrator commits to next-production (requires manual approval)
         ↓
Developer merges: next-production → live-production
         ↓
ArgoCD syncs to production cluster
```

---

## Reference Documentation

- [ArgoCD Source Hydrator](https://argo-cd.readthedocs.io/en/latest/user-guide/source-hydrator/)
- [Helm Dependency Management](https://helm.sh/docs/helm/helm_dependency/)
- [GitOps Best Practices](https://argoproj.github.io/argo-cd/operator-manual/declarative-setup/)

---

**Last Updated**: August 21, 2026
**Status**: Ready for Phase 2 implementation
**Created By**: Claude Code - Space Age GitOps Migration
