# Repository Context

This is an established declarative GitOps repository. It intentionally uses a
small set of shell scripts and Kubernetes resources rather than a general
framework or management layer. The repository is the source of truth; inspect
the existing files to discover their roles before changing them.

## Architecture

`applications/` is the single application source tree. Application metadata,
environment refs, ApplicationSets, Source Hydrator, Promoter, and Argo CD form
one connected source-of-truth chain. Understand the relevant chain before
editing an individual resource. Do not create a second source of truth or
modify a derived artifact when its source belongs elsewhere.

Use the simplest implementation already represented here. Do not add a
checkout, renderer, controller, packaging layer, runtime, or dependency merely
because it is familiar from another project. Repository files may be authored
source, generator input, or derived runtime state; determine which before
editing.

## Inspection

When the local repository is available, prefer direct, information-dense
filesystem inspection such as `tree`, `ls -la`, `cat`, `find`, `grep`, and
`sed`. Select commands that answer the questions relevant to the task; there
is no universal inspection checklist. For Kubernetes runtime questions, use
focused commands such as `kubectl get pods -A` only when runtime context is
needed. The goal is relevant context, not unrelated machine telemetry.

## GCP Bootstrap

The cloud bootstrap depends on persistent infrastructure that exists
independently of the compute instance:

- declared VPC network and subnet
- regional static external IP reservation
- firewall rules and their stable network tag
- service account and its IAM configuration

These names and identifiers are part of the infrastructure contract. Missing
persistent prerequisites indicate a broken environment and must fail clearly;
bootstrap scripts must not infer, recreate, or repair them.

The VM is disposable. Its lifecycle is:

```text
persistent infrastructure
        |
destroy disposable VM
        |
create VM with current at-boot.sh
        |
boot and retrieve at-login.sh
        |
manual Kubernetes bootstrap
```

Destroying the VM must not destroy or replace the static IP, network, subnet,
firewalls, service account, or IAM configuration. The replacement VM attaches
to those same resources and receives the existing firewall network tag.

## Three Stages

`bash/cloud/at-provision.sh` validates the persistent prerequisites, destroys
the named disposable VM when present, and creates its replacement with the
repository-supplied `at-boot.sh`.

`bash/cloud/at-boot.sh` is intentionally trivial. It only downloads the
canonical `at-login.sh` to `/root/at-login.sh` and makes it executable. It does
not provision infrastructure or install Kubernetes components.

`bash/cloud/at-login.sh` is the sole manual Kubernetes bootstrap entry point.
It installs the existing Kind, kubectl, and Helm tools, creates the Kind
cluster, applies the required CRDs and Argo CD resources, creates the GitHub
App Secret, and applies the ApplicationSets.

The login script must not clone the repository or leave a permanent working
copy on the small VM. It retrieves only required artifacts, uses temporary
storage for manifests and generated bootstrap material, and removes that
storage on exit. GitHub App credentials must be validated and handled only as
needed to create the Kubernetes Secret.

Preserve the three distinct responsibilities and the existing direct artifact
download approach. The repository should remain small, direct, and
declarative.
