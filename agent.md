# Bootstrap Entry Point

`kind-local.sh` performs the following bootstrap sequence:

1. Recreates the Kind cluster:

```bash
kind delete cluster
kind create cluster --config kind.yaml
```

2. Waits for cluster readiness:

```bash
sleep 60
```

3. Generates the Authentik secret:

```bash
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 36)
```

4. Applies base infrastructure:

```bash
kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes/kubernetes?ref=main" | kubectl apply -f -
```

5. Creates the Authentik secret:

```bash
kubectl create secret generic authentik-secret-key \
  --namespace authentik \
  --from-literal=secret_key="$AUTHENTIK_SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
```

6. Deploys Argo CD:

```bash
kubectl kustomize --enable-helm "github.com/global-cloudwork/kubernetes/applications/argocd?ref=main" \
| kubectl apply --server-side --force-conflicts -f -
```

7. Applies core Argo CD resources:

```bash
kubectl apply -f app-project.yaml
kubectl apply -f application-set.yaml
kubectl apply -f gateway.yaml
```

8. Retrieves credentials:

```bash
./get-credentials.sh
```

---

# Kind Cluster Configuration

Source: `environment/on-site/scripts/kind.yaml`

The cluster is defined as:

* Kubernetes Kind API: `kind.x-k8s.io/v1alpha4`
* One control-plane node
* Port mappings:

| Host | Container |
| ---- | --------- |
| 80   | 30080     |
| 443  | 30443     |

Immediately after creation, the cluster contains only the Kind control-plane node and port configuration. No application resources are installed until later bootstrap steps.

---

# Declarative Resource Sources

## 1. Base Infrastructure and CRDs

Source:

`github.com/global-cloudwork/kubernetes/kustomization.yaml`

The root Kustomization applies:

### Namespaces

From `namespace.yaml`:

* argocd
* core
* data
* edge
* tenant
* gateway
* homepage
* authentik

### Argo CD CRDs

Loaded from:

* `application-crd.yaml`
* `appproject-crd.yaml`
* `applicationset-crd.yaml`

Source:
`argoproj/argo-cd` stable manifests

### Cert-Manager CRDs

Source:

`cert-manager/releases/v1.13.0/cert-manager.crds.yaml`

### Gateway API CRDs

Sources:

* `gateway-api/v1.4.0/standard-install.yaml`
* `gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml`

Cilium CRDs exist only as commented entries and are not applied.

---

# 2. Authentik Secret

Source:

`kind-local.sh`

The secret is not repository-defined.

Generated:

```bash
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 36)
```

Created resource:

* Kind: Secret
* Name: `authentik-secret-key`
* Namespace: `authentik`
* Key: `secret_key`

---

# 3. Argo CD Deployment

Source:

`applications/argocd`

Defined by:

`applications/argocd/kustomization.yaml`

Components:

## Helm Chart

Chart:

* Name: `argo-cd`
* Repository: `https://argoproj.github.io/argo-helm`
* Namespace: `argocd`
* Version: `9.1.0`
* Release name: `argocd`
* CRDs included

Values:

```yaml
configs:
  params:
    server.insecure: "true"

server:
  service:
    type: ClusterIP
```

## Additional Resources

### Repository Secret

File:

`secret.yaml`

Creates:

* Secret: `repository-secret`
* Namespace: `argocd`
* Repository URL:
  `https://github.com/global-cloudwork/kubernetes`

### Argo CD ConfigMap Patch

File:

`config-map.yaml`

Updates:

`argocd-cm`

Enables:

```yaml
kustomize.buildOptions:
  --enable-helm --load-restrictor LoadRestrictionsNone
```

### Argo CD HTTPRoute

File:

`httproute.yaml`

Creates:

* Resource: `HTTPRoute`
* Name: `argocd-http-route`
* Namespace: `argocd`

Routing:

```
Host:
  argocd.promotesudbury.ca

Path:
  /

Backend:
  argocd-server:80
```

---

# 4. Core Argo CD Resources

Source:

`kubernetes/core`

## AppProject

File:

`app-project.yaml`

Creates:

* Kind: `AppProject`
* Name: `app-project`
* Namespace: `argocd`

Configuration:

* Empty source repositories
* Empty source namespaces
* Empty destinations
* Namespace resource blacklist configured

---

## ApplicationSet

File:

`application-set.yaml`

Creates:

* Kind: `ApplicationSet`
* Name: `cluster-apps`
* Namespace: `argocd`

Generator:

Git directory generator:

```yaml
repoURL:
  https://github.com/global-cloudwork/kubernetes.git

revision:
  main

directories:
  applications/*
```

Generated Applications use:

```yaml
repoURL:
  https://github.com/global-cloudwork/kubernetes.git

path:
  '{{ .path.path }}'

destination:
  namespace:
    '{{ .path.basename }}'
```

Sync policy:

* Automated sync
* Prune enabled
* Self-healing enabled
* CreateNamespace enabled
* Server-side apply enabled
* Respect ignore differences enabled

---

## Gateway

File:

`gateway.yaml`

Creates:

* Kind: `Gateway`
* Name: `gateway`
* Namespace: `gateway`

Configuration:

```yaml
gatewayClassName: traefik
```

Listener:

* Name: `http`
* Protocol: `HTTP`
* Port: `80`
* Routes allowed from all namespaces

---

# Deployment Timeline

## Step 1 — Create Cluster

Creates a fresh Kind cluster:

* One control-plane node
* Ports:

  * `80 -> 30080`
  * `443 -> 30443`

---

## Step 2 — Apply Infrastructure

Applies:

* Namespaces
* Argo CD CRDs
* Cert-Manager CRDs
* Gateway API CRDs

Source:

`kubernetes/kustomization.yaml`

---

## Step 3 — Create Authentik Secret

Creates:

```
Secret/authentik-secret-key
Namespace: authentik
```

Generated dynamically by the bootstrap script.

---

## Step 4 — Install Argo CD

Applies:

`applications/argocd`

Installs:

* Argo CD Helm release
* Repository secret
* ConfigMap patch
* HTTPRoute

---

## Step 5 — Apply Core Resources

Applies:

* `AppProject`
* `ApplicationSet`
* `Gateway`

---

## Step 6 — Retrieve Credentials

Runs:

```bash
./get-credentials.sh
```

Returns:

* Argo CD admin credentials
* UI endpoint:
  `http://localhost:30080`

---

# Declarative Relationships

## Argo CD → Repository

Defined by ApplicationSet:

Repository:

```
https://github.com/global-cloudwork/kubernetes.git
```

Branch:

```
main
```

Source path:

```
applications/*
```

Argo CD generates Applications from directories under `applications/*`.

---

## ApplicationSet → Applications

The Git directory generator creates Applications dynamically from repository folders.

---

## AppProject → Deployment Restrictions

`app-project` controls:

* Allowed repositories
* Allowed namespaces
* Allowed destinations
* Resource restrictions

---

## Gateway → HTTPRoute → Argo CD

Flow:

```
Gateway
  |
  | HTTP listener :80
  |
HTTPRoute
  |
  | argocd.promotesudbury.ca
  |
argocd-server :80
```

---

# Final Declarative State

The cluster contains:

## Namespaces

* argocd
* core
* data
* edge
* tenant
* gateway
* homepage
* authentik

## CRDs

* Argo CD Application
* Argo CD AppProject
* Argo CD ApplicationSet
* Cert-Manager CRDs
* Gateway API CRDs

## Argo CD Resources

* Helm deployment (`argo-cd`)
* Repository secret
* ConfigMap configuration
* AppProject
* ApplicationSet

## Networking

* Traefik Gateway
* Argo CD HTTPRoute

## Generated Secret

* `authentik-secret-key` in namespace `authentik`

All described state is derived only from:

* `environment/on-site/scripts/kind.yaml`
* `environment/on-site/scripts/kind-local.sh`
* `kubernetes/kustomization.yaml`
* `kubernetes/namespace.yaml`
* `applications/argocd/*`
* `kubernetes/core/*`

No runtime behavior or implicit architecture is inferred beyond what is declared in YAML, Kustomize, or Helm references.
