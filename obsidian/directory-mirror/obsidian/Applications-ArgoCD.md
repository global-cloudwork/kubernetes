---
title: "Applications / Argo CD Deployment"
deployment_method: "Argo CD ApplicationSet"
application_set:
  cluster_generator:
    clusters: ["development", "production", "testing"]
  scm_provider_generator: "customization.yaml file discovery"
applications_directory: "applications/"
components_per_environment:
  - core
  - data
  - edge
  - tenant
example:
  name: "Argo CD"
  path: "applications/argocd"
  customization:
    namespace: "argocd"
    httproute: "configured"
    helm_chart:
      version: "specified"
      overrides_inline: true
cilium:
  installed_via_applications: true
---

# Applications / Argo CD Deployment

Defines how all cluster applications are organized and deployed via Argo CD. Each application lives in its own subdirectory under `applications/`, with YAML manifests and any overrides required. An ApplicationSet combines a cluster generator and an SCM provider generator to deploy each application to the correct cluster. All environments receive the core components plus data, edge, and tenant extensions, including Cilium as an application.
