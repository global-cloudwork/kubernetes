The goal is to balance the task set to you, with the stability of my system. Don't ask questions, debug, act, assess, repeat until finished.

Read this file, tree the repository root, then cat files until comfortable before continuing.

# Not a normal kubernetes server

*!!! This is the pattern for the repo, maintain it and things will remain clean orginized. !!!*

## Bootstrap - Phoenix-style GitOps cluster creation
./scripts/omen/bootstrap.sh --phase 1
# Then after setup:
./scripts/omen/bootstrap.sh --phase 2 <github-username> <github-pat-token>

## Test Connection 
curl -H "Host: homepage.local" http://homepage.local:30080

The mature reasons for this aproach are as follows:
1. Simplicity
2. Orginization
3. Natural language understanding
4. Version control
5. Disaster recovery
6. Rapid prototyping
7. Declarative stateless server configurations
8. Versatility

## The Unified bootstrap.sh Script

This script bootstraps the entire kubernetes cluster. Destroys the existing version and deploys the version currently stored in Git. Think phoenix-style gitops.

**Phase 1**: Creates Kind cluster + deploys infrastructure (CRDs, namespaces, ApplicationSets)
**Phase 2**: Enables Source Hydrator + creates GitHub write secret for manifest rendering

Deploying single files or applying via kubectl directly is poor form for this project. Aim to modify declaritive specifications in git, then bootstrap the cluster to deploy them.

Details: /scripts/omen/bootstrap.sh and /scripts/omen/kind-config.yaml

## Manifest locations 

1. Initilization - /kubernetes/kustomization.yaml this includes CRD's namespaces, and other required manifests.
2. Server Manifests - /kubernetes/core/*.yaml
   1. Located in this folder is an applicationset that deploys all the applications in section 3
3. App Deployment - /applications/**/kustomization.yaml, and paired manifests
   1. The helmCharts: section deploys each of the applications via helm chart
   2. The valuesInline: section makes for clean and readable values.yaml overides
   3. The Resources: section contains app specific manifests.

## Guidelines:
1. Edit as few files as possible
2. Create as few files as possible
3. Liberal use of terminal commands to debug and understand
4. All manifest files should contain only one manifest, or multiple manifests of the same type. This allows the name of the file to describe its contents. eg. httproute.yaml

## Name Examples

1. App specific:  2 roles related to traefik. Both should be contained in the file role.yaml file contained in /applications/traefik/ directory.
2. Cluster specific: Gateway for the cluster. Located in /kubernetes/core/ and named acordingly gateway.yaml.

## Bad Form
1. cat <<EOF | kubectl apply -f -
2. 
