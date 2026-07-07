# Declarative Deployment Summary: kind-local.sh

Scope
- This document enumerates declarative specifications that drive the local deployment orchestrated by kind-local.sh, as defined by YAML manifests and Helm/Kustomize configurations in the repository. Runtime steps (e.g., secret generation, kubeconfig fetch) are noted for context but are not treated as declarative specifications themselves.

Cluster provisioning (declarative)
- environment/on-site/scripts/kind.yaml defines a single control-plane node with host port mappings:
  - containerPort 30080 maps to hostPort 80
  - containerPort 30443 maps to hostPort 443

Namespaces (declarative)
- kubernetes/namespace.yaml declares the following namespaces: argocd, core, data, edge, tenant, gateway, homepage, authentik

Gateway (Gateway API, declarative)
- kubernetes/core/gateway.yaml declares a Gateway resource:
  apiVersion: gateway.networking.k8s.io/v1
  kind: Gateway
  metadata:
    name: gateway
    namespace: gateway
  spec:
    gatewayClassName: traefik
    listeners:
      - name: http
        protocol: HTTP
        port: 80
        allowedRoutes:
          namespaces:
            from: All

Traefik deployment (Helm via Kustomize)
- applications/traefik/kustomization.yaml declares a Traefik Helm chart with:
  - repo: https://traefik.github.io/charts
  - namespace: traefik
  - version: 37.1.0
  - releaseName: traefik
  - valuesInline:
    - providers.kubernetesGateway.enabled: true
    - gateway.enabled: false
    - service.type: NodePort
  - ports:
    - web: port: 80, nodePort: 30080
    - websecure: port: 443, nodePort: 30443

Argocd deployment (Helm via Kustomize)
- applications/argocd/kustomization.yaml declares:
  - namespace: argocd
  - version: 9.1.0
  - releaseName: argocd
  - includeCRDs: true
  - resources: secret.yaml
  - patches: config-map.yaml targeting Argocd ConfigMap argocd-cm
  - valuesInline:
    - configs.params.server.insecure: "true"
    - server.service.type: ClusterIP

Argocd secret (declarative repository secret)
- applications/argocd/secret.yaml declares a Secret named repository-secret in namespace argocd with a URL to the GitHub repository:
  - url: https://github.com/global-cloudwork/kubernetes

Argocd HTTPRoute (Gateway API, declarative)
- applications/argocd/httproute.yaml declares an HTTPRoute for Argo CD:
  - apiVersion: gateway.networking.k8s.io/v1
  - kind: HTTPRoute
  - metadata: name: argocd-http-route, namespace: argocd
  - spec:
    - parentRefs: [{ name: gateway, sectionName: https }]
    - hostnames: [ argocd.promotesudbury.ca ]
    - rules:
      - matches: [{ path: { type: PathPrefix, value: "/" } }]
        backendRefs: [{ name: argocd-server, port: 80 }]

Authentik deployment (Helm via Kustomize)
- applications/authentik/kustomization.yaml declares:
  - namespace: authentik
  - version: 2026.5.3
  - releaseName: my-authentik
  - existingSecret: authentik-secret-key
  - postgresql.enabled: true
  - redis.enabled: true
  - error_reporting.enabled: false

Applications/authentik/namespace.yaml
- declares Namespace: authentik

Authentik secret reference (declarative linkage)
- The Helm values reference existingSecret: authentik-secret-key; actual secret data is provided externally and not declared in this repository.

Homepage deployment (Helm via Kustomize)
- applications/homepage/kustomization.yaml declares:
  - namespace: homepage
  - version: 1.8.1
  - releaseName: homepage
  - valuesInline:
    - service.type: ClusterIP

Homepage HTTPRoute (Gateway API, declarative)
- applications/homepage/httproute.yaml declares an HTTPRoute for Homepage:
  - apiVersion: gateway.networking.k8s.io/v1
  - kind: HTTPRoute
  - metadata: name: homepage, namespace: homepage
  - spec:
    - parentRefs: [{ name: gateway, namespace: gateway }]
    - hostnames: [ homepage.local ]
    - rules:
      - backendRefs: [{ name: homepage, port: 80 }]

Resource sources and bootstrap flow (declarative)
- kubectl kustomize --enable-helm github.com/global-cloudwork/kubernetes?ref=main is applied to provision cluster scope CRDs and base resources (Argo CD CRDs, Cert-Manager CRDs, Gateway API CRDs, TLSRoutes).
- kubectl kustomize --enable-helm github.com/global-cloudwork/kubernetes/applications/argocd?ref=main is applied for Argo CD deployment and configuration (secret.yaml, config-map.yaml patches).
- Core resources app-project.yaml, application-set.yaml and gateway.yaml are applied from raw URLs:
  - https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/core/app-project.yaml
  - https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/core/application-set.yaml
  - https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/core/gateway.yaml
- The deployment uses the GitHub-based Helm charts and Kustomize to integrate Helm releases declaratively.
- The final credentials for accessing clusters are retrieved via get-credentials.sh after resources are applied (non-declarative runtime step).

Hostnames for routing (declarative)
- argocd.promotesudbury.ca
- homepage.local

Notes
- The deployment relies on Kubernetes Gateway API resources and Helm charts to declaratively install and configure components.
- Secrets declared declaratively include Argocd repository-secret. Authentik uses an existingSecret reference to an externally managed secret.
- Runtime secret generation for authentik is performed as part of the script and is not expressed as a declarative manifest in this repository.

End of declarative summary for kind-local.sh
