# Space-Age GitOps Architecture

## 1. One repository is the project source of truth

This repository is the complete source of truth for the project.

The repository intentionally stays small. Directories, files, and abstractions should exist because the system needs them, not because they are conventional in Kubernetes repositories.

```text
.
├── agents.md
├── applications/
│   ├── argocd/
│   ├── authentik/
│   ├── cert-manager/
│   ├── homepage/
│   ├── n8n/
│   ├── neo4j/
│   ├── traefik/
│   └── wireguard/
├── bash/
│   ├── cloud/
│   └── omen/
└── kubernetes/
    ├── bootstrap/
    ├── argocd/
    ├── gateway/
    ├── promotion/
    ├── repository/
    └── secrets/
```

`applications/` is the application source tree.

There is **one application tree**.

Do not create separate application trees for development, staging, or production.

An application may use whatever source representation is appropriate:

* plain Kubernetes YAML
* Helm
* another Argo CD-supported source mechanism

The simplest appropriate representation should be preferred.

Do not introduce an additional rendering or packaging layer merely because it is common in other Kubernetes repositories.

Do not copy an upstream Helm chart into this repository unless this project actually owns and maintains that chart.

`main` is the authoritative application catalog.

Conceptually:

```text
main
 │
 └── applications/
     ├── traefik/
     ├── n8n/
     ├── neo4j/
     └── ...
```

`main` describes **what applications exist and how they are sourced**.

Deployment state is handled separately by the environment refs.

---

## 2. Bootstrap is a separate lifecycle phase

Bootstrap exists to establish the minimum GitOps control plane on an otherwise empty Kubernetes cluster.

Conceptually:

```text
empty Kubernetes cluster
        │
        ▼
     bootstrap
        │
        ▼
GitOps control plane
        │
        ▼
   GitOps takes over
```

Bootstrap may contain the small amount of imperative tooling required to establish the initial control plane.

It may also use whatever rendering mechanism makes the bootstrap resources simple and deterministic.

That tooling belongs to the bootstrap lifecycle.

It does **not** define how normal applications are deployed.

The desired boundary is:

```text
bootstrap
   │
   │ establishes
   ▼
Argo CD + ApplicationSet + Source Hydrator + Promoter
   │
   │ manage
   ▼
application deployment state
```

After bootstrap, the cluster should converge from Git.

Disaster recovery should therefore require only enough imperative tooling to establish the initial control plane. Once that control plane is operational, Git becomes the source of truth again.

---

## 3. Application definitions live in one application tree

Each application has one source definition under `applications/`.

For example:

```text
applications/
└── traefik/
    └── config.json
```

A simple application contract may look like:

```json
{
  "app": "traefik",
  "enabled": true,
  "namespace": "traefik",

  "source": {
    "type": "helm",
    "path": "applications/traefik"
  },

  "versions": {
    "development": "3.5.0",
    "staging": "3.5.1",
    "production": "3.4.0"
  }
}
```

The application contract describes the application.

It should not contain controller-specific promotion machinery unless that information genuinely belongs to the application itself.

In particular, do not put environment-specific directories into the application tree merely to represent deployment environments.

Avoid:

```text
applications/
├── development/
├── staging/
└── production/
```

Prefer:

```text
applications/
├── traefik/
├── n8n/
└── neo4j/
```

The application tree answers:

> **What applications does this project contain?**

---

## 4. ApplicationSet discovers applications and environments

ApplicationSet is the discovery and Application-generation layer.

It combines two independent dimensions:

1. the application catalog from `main`
2. the active environment branches discovered from Git

Conceptually:

```text
                         Git repository
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
        application catalog          active environment
              main                       branches
                │                           │
                ▼                           ▼
       Git file generator            SCM Provider
                │                           │
                └─────────────┬─────────────┘
                              ▼
                           Matrix
                              │
                              ▼
                       ApplicationSet
                              │
                              ▼
                       Argo CD Applications
```

The application catalog comes from:

```text
applications/*/config.json
```

on `main`.

The environment dimension comes from the active environment branches:

```text
environment/development
environment/staging
environment/production
```

ApplicationSet should **not** treat the `*-next` branches as deployment targets.

Therefore:

```text
main                         → ignored as environment
environment/development     → active target
environment/development-next → ignored
environment/staging         → active target
environment/staging-next    → ignored
environment/production      → active target
environment/production-next → ignored
```

The ApplicationSet answers:

> **What Applications should Argo CD manage right now?**

It does not own promotion.

It does not create environment-specific application trees.

It does not decide how an application moves from development to staging to production.

---

## 5. Environment is a Git ref, not an application directory

The environment dimension is represented by Git refs.

```text
main

environment/development
environment/development-next

environment/staging
environment/staging-next

environment/production
environment/production-next
```

The active environment branches are deployment targets.

The `*-next` branches are proposed state used by the promotion workflow.

The distinction is intentional:

```text
active branch
    │
    │ deployed state
    ▼
Argo CD
```

versus:

```text
*-next branch
    │
    │ proposed state
    ▼
Promoter
```

Do not introduce:

```text
applications/development/
applications/staging/
applications/production/
```

to represent this state.

The same application moves through Git refs.

Conceptually:

```text
                    same application

                         traefik
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
        development      staging       production
```

Git history records how that state arrived where it is.

---

## 6. Rendering and hydration are implementation details

Application source is not necessarily identical to the final Kubernetes manifests.

The source-processing and hydration pipeline turns application source into deployable Kubernetes state.

Conceptually:

```text
application source
       │
       ▼
Argo CD source processing
       │
       ▼
rendered Kubernetes manifests
       │
       ▼
hydrated Git state
```

The rendering mechanism depends on the application.

For example:

```text
Helm source
    │
    ▼
rendered manifests
```

or:

```text
plain YAML
    │
    ▼
rendered manifests
```

The repository should not impose a universal packaging mechanism.

The important architectural boundary is:

> **The application source describes what should be rendered. Hydration produces the declarative state that is promoted and reconciled.**

Promoter should not care whether the resulting manifests originally came from Helm or plain YAML.

It promotes Git state.

Argo CD reconciles the active Git state.

---

## 7. Source Hydrator produces proposed deployment state

Source Hydrator is responsible for taking the application's source and producing hydrated Kubernetes manifests.

The conceptual flow is:

```text
main
 │
 │ application source
 ▼
Source Hydrator
 │
 │ render
 ▼
environment/<environment>-next
```

For example:

```text
applications/traefik
        │
        ▼
Source Hydrator
        │
        ▼
environment/development-next
```

The `*-next` ref is deliberately not an ApplicationSet deployment target.

It is proposed state.

This creates a clean handoff:

```text
Source Hydrator
      │
      │ produces
      ▼
 environment/*-next
      │
      │ consumed by
      ▼
   Promoter
```

Source Hydrator should not own promotion policy.

Promoter should not own rendering policy.

Each system has one job.

---

## 8. Promoter moves application state forward

Promoter is responsible for promotion.

It moves an application's hydrated state between the ordered environment refs.

Conceptually:

```text
development-next
       │
       │ promotion
       ▼
development
       │
       │ promotion
       ▼
staging
       │
       │ promotion
       ▼
production
```

Promoter owns the decision and mechanics of moving state forward.

It may use commit status, pull requests, approval gates, or other promotion conditions.

Those are promotion concerns.

They should not be embedded into the application source merely to make the deployment system work.

---

## 9. Applications promote independently

Environment branches are shared.

Applications are not.

Each application has its own `PromotionStrategy` and `activePath`.

For example:

```yaml
metadata:
  name: traefik

spec:
  activePath: applications/traefik
```

Another application can have:

```yaml
metadata:
  name: n8n

spec:
  activePath: applications/n8n
```

This allows:

```text
environment/development
environment/staging
environment/production
```

to remain shared environment refs while individual applications progress independently.

Conceptually:

```text
                         ONE REPOSITORY
                              │
                              ▼
                       applications/
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           traefik            n8n           neo4j
              │               │               │
              ▼               ▼               ▼
         activePath       activePath       activePath
              │               │               │
              └───────────────┼───────────────┘
                              ▼
                    shared environment refs
```

A Traefik promotion therefore does not inherently promote n8n.

The shared branch is the environment.

The `activePath` is the application's promotion scope.

---

## 10. `activePath` belongs to Promoter

`activePath` describes how Promoter scopes an application's promotion.

It is therefore Promoter configuration, not application source configuration.

Do not put:

```json
{
  "promotion": {
    "activePath": "applications/traefik"
  }
}
```

into every application's `config.json` merely because Promoter needs the value.

The application already has an identity and a path:

```text
app = traefik
      │
      ▼
applications/traefik
```

Keep application source concerned with the application.

Keep promotion configuration concerned with promotion.

---

## 11. Argo CD reconciles active state

Argo CD is the final reconciliation layer.

ApplicationSet determines which Applications exist.

Source Hydrator produces hydrated state.

Promoter advances that state.

Argo CD reconciles the active environment state into Kubernetes.

The complete lifecycle is:

```text
                         main
                          │
                          ▼
                  application source
                          │
                          ▼
                    ApplicationSet
                          │
                          ▼
                       Argo CD
                          │
                          │ source processing
                          ▼
                   Source Hydrator
                          │
                          ▼
                environment/*-next
                          │
                          ▼
                       Promoter
                          │
                          ▼
                 environment/<env>
                          │
                          ▼
                       Argo CD
                          │
                          ▼
                     Kubernetes
```

The important distinction is that Argo CD does not need to know how promotion happened.

It only needs the active desired state.

---

## 12. The system has deliberately boring boundaries

Each component should have one primary responsibility.

| Component        | Responsibility                                |
| ---------------- | --------------------------------------------- |
| `main`           | Application catalog and authored source       |
| `applications/`  | Application definitions and source            |
| ApplicationSet   | Discover applications and active environments |
| Source Hydrator  | Render source into hydrated Kubernetes state  |
| `*-next` refs    | Proposed deployment state                     |
| Promoter         | Move application state between environments   |
| Environment refs | Active deployment state                       |
| Argo CD          | Reconcile active state into Kubernetes        |
| Bootstrap        | Establish the GitOps control plane            |

Do not make one component compensate for another.

In particular:

* ApplicationSet should not become a promotion engine.
* Promoter should not become a renderer.
* Argo CD should not become the source-of-truth database.
* Application source should not become a description of controller internals.
* Environment state should not become a directory hierarchy.
* Bootstrap should not become the permanent deployment mechanism.

---

## 13. Prefer the smallest mechanism that satisfies the requirement

This repository intentionally rejects unnecessary abstraction.

Before adding a directory, file, controller, generator, overlay, wrapper, or transformation layer, ask:

> **What concrete problem does this solve?**

If plain YAML solves the problem, use plain YAML.

If a supported Helm source solves the problem, use Helm.

If ApplicationSet can discover something directly, do not create another inventory system.

If Git refs already represent the environment state, do not create another environment hierarchy.

If Promoter already owns promotion, do not encode promotion logic into application source.

If a controller already provides the required reconciliation behavior, do not write a custom controller.

Complexity should be earned by an actual requirement.

---

## 14. The architectural invariant

The entire system can be summarized as:

```text
Repository says what applications exist.

ApplicationSet says what gets reconciled.

Source Hydrator says how source becomes deployable state.

Git refs say where that state is in the lifecycle.

Promoter says what state moves forward.

Argo CD makes active state real.
```

Or, more compactly:

```text
                    SOURCE
                      │
                      ▼
               ApplicationSet
                      │
                      ▼
                  Hydration
                      │
                      ▼
                    *-next
                      │
                      ▼
                  Promoter
                      │
                      ▼
                 environment/*
                      │
                      ▼
                   Argo CD
                      │
                      ▼
                  Kubernetes
```

The goal is not to build the most elaborate GitOps system.

The goal is to make the deployment lifecycle understandable enough that each component can remain simple.

**One repository.
One application tree.
One application definition per application.
Shared environment refs.
Independent promotion paths.
Generated state where generation is actually required.
No abstraction without a reason.**

Applicationset reference 

{
  (...)
  "app": {
    "source": "https://github.com/argoproj/argo-cd",
    "revision": "HEAD",
    "path": "applicationset/examples/git-generator-files-discovery/apps/guestbook"
  }
  (...)
}

kind: ApplicationSet
# (...)
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - git:
      repoURL: https://github.com/argoproj/argo-cd.git
      files:
      - path: "apps/**/config.json"
  template:
    spec:
      project: dev-team-one # project is restricted
      source:
        # developers may customize app details using JSON files from above repo URL
        repoURL: {{.app.source}}
        targetRevision: {{.app.revision}}
        path: {{.app.path}}
      destination:
        name: production-cluster # cluster is restricted
        namespace: dev-team-one # namespace is restricted

Applicationset example developed 

apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: applications
  namespace: argocd

spec:
  goTemplate: true
  goTemplateOptions:
    - missingkey=error

  generators:

    - matrix:
        generators:

          # 1. Discover applications and their metadata
          - git:
              repoURL: https://github.com/example/platform.git
              revision: main
              files:
                - path: applications/*/config.json

          # 2. Generate the environment dimension
          - list:
              elements:
                - environment: development
                  hydratedBranch: environment/development

                - environment: staging
                  hydratedBranch: environment/staging

                - environment: production
                  hydratedBranch: environment/production

  # IMPORTANT:
  # selector is on the ApplicationSet generator result,
  # not nested inside matrix.generators.
  selector:
    matchExpressions:
      - key: enabled
        operator: In
        values:
          - "true"

  template:
    metadata:
      name: '{{.app}}-{{.environment}}'

      labels:
        app: '{{.app}}'
        environment: '{{.environment}}'

    spec:
      project: default

      # Source Hydrator goes here...


      applications/traefik/config.json

I'd make this the application contract:

{
  "app": "traefik",
  "enabled": true,
  "namespace": "traefik",

  "source": {
    "type": "helm",
    "path": "applications/traefik"
  },

  "versions": {
    "development": "3.5.0",
    "staging": "3.5.1",
    "production": "3.4.0"
  }
}

Notice what's gone:

"repoURL": "...",
"chart": "traefik",
"promotion": {
  "activePath": "..."
}

The Git repository is already the source repository.

And activePath belongs to Promoter, not the application contract.

applications/traefik/Chart.yaml
apiVersion: v2
name: traefik-platform
description: Platform wrapper for Traefik
type: application
version: 0.1.0

dependencies:
  - name: traefik
    repository: https://traefik.github.io/charts
    version: 3.5.0

But here's the important architectural question:

I would not actually put the version here.

The whole point of your environment-specific version selection is that:

development → 3.5.0
staging     → 3.5.1
production  → 3.4.0

So I'd instead use a templated/generated dependency version or, preferably, keep the Helm dependency version fixed and make the environment-specific revision part of the hydration source configuration if your exact Argo CD version supports the necessary Helm dependency behavior.

This is precisely where I would test the Source Hydrator behavior before committing to the wrapper-chart approach.

ApplicationSet

I would rebuild the ApplicationSet around two dimensions:

Git application catalog
SCM-discovered active environment

The application catalog stays on main.

The environment branches are discovered independently.

apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:
  name: applications
  namespace: argocd

spec:
  goTemplate: true

  goTemplateOptions:
    - missingkey=error

  generators:
    - matrix:
        generators:

          # ------------------------------------------------------------
          # APPLICATIONS
          #
          # main is the application catalog.
          #
          # This is intentionally NOT read from the environment branch.
          # ------------------------------------------------------------
          - git:
              repoURL: https://github.com/example/platform.git
              revision: main

              files:
                - path: applications/*/config.json

          # ------------------------------------------------------------
          # ENVIRONMENTS
          #
          # Only active environment branches become Argo CD targets.
          #
          # main                    -> ignored
          # environment/*-next      -> ignored
          # environment/development -> included
          # environment/staging     -> included
          # environment/production  -> included
          # ------------------------------------------------------------
          - scmProvider:
              github:
                organization: example
                allBranches: true

              filters:
                - repositoryMatch: '^platform$'
                  branchMatch: '^environment/(development|staging|production)$'

              values:
                environment: '{{.branch | replace "environment/" ""}}'

  # --------------------------------------------------------------
  # Only explicitly enabled applications are generated.
  # --------------------------------------------------------------
  selector:
    matchExpressions:
      - key: enabled
        operator: In
        values:
          - "true"

  template:

    metadata:
      name: '{{.app}}-{{.values.environment}}'

      labels:
        app: '{{.app}}'
        environment: '{{.values.environment}}'

    spec:
      project: default

      # ------------------------------------------------------------
      # SOURCE HYDRATOR
      #
      # drySource = Git source to render
      # syncSource = active hydrated environment
      # hydrateTo = Promoter staging branch
      # ------------------------------------------------------------
      sourceHydrator:

        drySource:
          repoURL: https://github.com/example/platform.git
          path: '{{.source.path}}'
          targetRevision: main

        syncSource:
          repoURL: https://github.com/example/platform.git
          targetBranch: 'environment/{{.values.environment}}'
          path: '{{.source.path}}'

        hydrateTo:
          targetBranch: 'environment/{{.values.environment}}-next'

      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.namespace}}'

      syncPolicy:
        automated:
          prune: true
          selfHeal: true

The important thing here is that ApplicationSet isn't trying to manufacture the hydrated branch itself.

It merely says:

this app
+
this environment
=
this Application

Source Hydrator handles rendering and writing.

Promoter handles moving the result.

That's the separation I'd keep.

Then Promoter owns this

For Traefik:

apiVersion: promoter.argoproj.io/v1alpha1
kind: PromotionStrategy

metadata:
  name: traefik
  namespace: argocd

spec:
  gitRepositoryRef:
    name: platform

  activePath: applications/traefik

  orderCommitStatusRef:
    group: promoter.argoproj.io
    kind: DependentsSuccessfulCommitStatus
    name: traefik

  environments:
    - branch: environment/development

    - branch: environment/staging

    - branch: environment/production

Current Promoter requires an explicit ordering gate in newer versions; the old implicit linear ordering was removed in 0.39. A DependentsSuccessfulCommitStatus is the documented mechanism for the normal linear pipeline.

And this is where your activePath really belongs.

Promoter documents that monorepos can share one active branch per environment while independently promoting applications using:

activePath: applications/traefik

and that its proposed branches become:

environment/development-next/applications/traefik

etc.

That is a very important correction to our previous mental model.

The resulting flow

Now the whole thing becomes:

                         main
                          │
                          │
                  applications/*
                    config.json
                          │
                          ▼
                  ┌───────────────┐
                  │ ApplicationSet│
                  └───────┬───────┘
                          │
             ┌────────────┴────────────┐
             │                         │
        application                 environment
         metadata                    discovery
             │                         │
             └────────────┬────────────┘
                          │
                          ▼
                     Application
                          │
                          ▼
                   Source Hydrator
                          │
                    render Git source
                          │
                          ▼
                environment/*-next
                          │
                          ▼
                      Promoter
                          │
                  promotion PR/merge
                          │
                          ▼
                environment/development
                          │
                          ▼
                      Argo CD
                          │
                          ▼
                       cluster
