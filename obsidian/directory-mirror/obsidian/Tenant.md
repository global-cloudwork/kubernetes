---
title: "Tenant"
name: "Tenant ApplicationSet"
generators:
  - type: "cluster"
    clusters: ["development", "production", "testing"]
  - type: "scm_provider"
    discovery: "customization.yaml file discovery"
mapping_logic: "Files named customization.yaml define application-to-cluster mappings"
example:
  application: "Vault"
  target_cluster: "development"
---

# Tenant

Describes the ApplicationSet that combines a cluster generator (dev, prod, test) with an SCM provider generator. The SCM generator discovers `customization.yaml` files in each application’s subdirectory to determine which cluster each application should be deployed to. For example, the Vault application’s customization file will deploy it to the development cluster.
