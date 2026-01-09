kubectl -n default patch secret argocd-secret \
  -p '{"stringData": {"server.secretkey": "'$(openssl rand -base64 32)'"}}'



# 📘 Repository Directory & Documentation Index

This document contains instructions on how to navigate the documentation.

## Users teritory

<!-- USER-COMMENTS-START (do not change) -->

<!-- USER-COMMENTS-END (do not change) -->

architecture: bash, rke2, cilium installed using helm

core applications: cilium,cert-manager,argocd

tenant applications: actualbudget,cockatrice,erpnext,example,foundry-vtt,homepage,keycloak,longhorn,n8n,neo4j,open-webui,vaultwarden

networking: cluster issuer for gateway annotation 


## Repository Structure and Documentation

.
├── applications
├── base
│   ├── core
│   ├── data
│   ├── edge
│   └── tenant
├── clusters
├── documentation
├── scripts
├── tests

### Directory Overview

## Repository Structure
- `applications/` – Deployment configs for tenant and core apps (kustomize + optional Helm values).
- `base/`
    - `applications/` – core appliccations
    - `core/` – Core components
    - `data/` – database, secrets
    - `edge/` – gateway, network policy
    - `tenant/` – applications
- `clusters/` – Cluster-specific initialization scripts and configuration.
- `documentation/`
- `scripts/` - init, infra, functions, tests

## Guidelines

- directory names - lowercase, hyphens, descriptive, plural for sets
- files names - lowercase, hyphens, reflecting their function
- Kubernetes manifests are named after their types: e.g., `deployment.yaml`, `service.yaml`, `ingress.yaml`, corresponding to deployment, service, ingress resources.

## Key Files and Usage

- `base/kustomization.yaml`: central CRD and bootstrap resources.
- `base/core/application-set.yaml`: deploys core components via ArgoCD.
- Application-specific `kustomization.yaml` and related files handle deployment.
- Scripts like `upload-key.sh` and `kubernetes.sh` assist with secret management and cluster interactions.
- Cluster bootstrap via `clusters/*/init.sh`.




c) Your stack and how it fits together (and gaps to fill)

You already have the core pieces:

Infrastructure: RKE2 (Kubernetes), Cilium for networking/security, ArgoCD for GitOps / app deployment, cert-manager for TLS, Keycloak for identity/Sso.

Workflow/automation layer: n8n for workflow orchestration, your Git repository (DRY patterns) for tenants/deployments, Helm + ArgoCD for provisioning.

Data/metadata layer: Neo4j with schema.org schemas (strong object typing) to provide a graph database of metadata/context.

Local LLM/agent UI: Open WebUI for interacting with LLMs on-prem, offline.


Agentic frameworks / state-based machines for LLMs & autonomous workflows

Function / Role: Orchestrate multi-step reasoning, maintain state, call external tools (APIs, n8n flows).

Notes: Can live as a workflow layer inside n8n. Think of it as agent orchestration and lifecycle management.

Tooling that optimises prompts (not just examples)

Function / Role: Performs optimisation passes over prompt variants; measures accuracy/cost/safety metrics; picks the best.

Notes: Automatable in n8n or standalone microservice; think gradient-free optimiser using feedback loops.

Open-source toolkit for prompt optimisation (GREATERPROMPT, etc.)

Function / Role: Toolkit reference implementation for prompt optimisation tooling.

Notes: You might wrap this as a local service with n8n connectors.

Open-source platform for context-aware AI guardrails (OpenGuardrails)

Function / Role: Central rules engine for detecting prompt injection, data exfiltration, unsafe output.

Notes: Integrates with CI/CD and runtime interceptors.

Optimisation, evaluation, feedback loops, prompt versioning

Function / Role: Combines prompt store + evaluation history + scoring + Git-like versioning.

Notes: Crucial to track prompt lineage (hash → version → metrics). Could persist metadata in Neo4j.

Local/edge LLM hosting and state-machines (OpenWebUI + persistent context)

Function / Role: Host local models with session memory; persist conversation state; connect to autonomous workflows.

Notes: Ideal for data-sovereign tenants.

Graph memory layer (Neo4j + vector)

Function / Role: Persist agent state, embeddings, relationships, metadata, prompt history.

Notes: Neo4j vector indexes can coexist with schema.org graph typing.

Guardrail 3-fold system

Function / Role:

PRGuard – Pull-request scanning for static policy checks in Argo/GitOps.

PromptGuard – Prompt + output scanning for runtime LLM I/O validation.

WideGuard – Observability and anomaly detection for safety and compliance.

Notes: Each sub-guard can be modular n8n nodes or controllers.

Billing + frontend orchestration (n8n + TS UI)

Function / Role: Automates metering, usage reports, invoice triggers, via n8n workflows; provides a TypeScript UI for customer dashboards.

Notes: Integrates with Keycloak for auth, and Argo events for tenant lifecycle.


Applications (Core Components to Deploy)

Agent Operations Service – orchestrates LLM-based state machines and agent workflows; implemented through n8n flows that handle multi-step reasoning, tool calling, and persistence.

Prompt Operations Service – manages prompt templates, evaluations, optimisation cycles, and versioning; stores prompts as YAML files in a Git repository.

Graph Memory Service – built on Neo4j with schema.org-typed objects and vector index support; used to store relationships, embeddings, and contextual metadata.

Edge Language Model Host – Open WebUI for local or edge-based LLM hosting with session persistence; connects to the Graph Memory and Prompt Operations services.

Guardrail System – three-layer safety framework (pull request checking, prompt checking, and system-wide safety).

Billing and Usage Service – n8n workflows and a placeholder REST application that handle metering, usage logging, and invoicing events.

Identity and Access Service – Keycloak for authentication, authorization, and tenant isolation.

Deployment and Orchestration – ArgoCD and Helm for GitOps-based discovery and deployment of all applications and tenant environments.

Networking and Security Layer – Cilium for zero-trust networking, observability, and policy enforcement.

Certificate Management – cert-manager for internal and external TLS provisioning.

## Data (Persistent and Transient Stores)

### Graph Memory Database – Neo4j with Vector Indexing
- Serves as the unified data layer for all persistent storage.  
- Stores agents, entities, relationships, embeddings, prompts, metadata, billing records, logs, metrics, and workflow execution states.  
- Enables graph-based querying, semantic reasoning, and retrieval-augmented generation (RAG) using embedded vectors.

### Cache Layer – Redis
- Handles transient data such as session context, short-term agent memory, task queues, and temporary workflow state.  
- Used for caching frequently accessed graph queries and computed embeddings to improve performance.

### Prompt Repository
- Prompts and evaluation results are versioned as nodes and relationships within Neo4j, replacing the external Git repository.

### Billing, Logs, and Metrics
- All billing transactions, observability data, and guardrail/security events are stored as graph nodes and relationships in Neo4j, providing traceable lineage and contextual insights.

### Workflow Metadata
- n8n execution states, trigger histories, and agent transitions are persisted in Neo4j.  
- Redis supports fast transient caching for active workflows.

# Guardrail Success Requirements

1. **Pull Request Guard**
   - Detect misconfigurations, unsafe code, missing policies, or cost rules.
   - Integrate with CI/CD (ArgoCD/GitHub Actions) to block bad merges.
   - Maintain version-controlled, auditable policy definitions.
   - Provide clear, explainable feedback in PRs.

2. **Prompt Guard**
   - Intercept all prompts and outputs to detect unsafe, injected, or sensitive content.
   - Integrate with Cost Guard before execution.
   - Log decisions without storing sensitive text.
   - Operate with minimal latency.

3. **Wide Guard**
   - Collect logs, metrics, and events from all guards and agents.
   - Detect anomalies in usage, cost, or unsafe behavior.
   - Trigger alerts or halt automation flows when thresholds are exceeded.
   - Provide centralized observability/dashboard for all guard activity.

4. **Cost Guard**
   - Estimate input/output tokens and projected cost per prompt and model.
   - Enforce per-user, per-project, and monthly cost limits.
   - Integrate with Prompt Guard (pre-execution) and Wide Guard (monitoring).
   - Take policy-driven actions: block, truncate, downgrade model, or alert.
   - Log estimates, actions, and cumulative usage for transparency.

5. **Overall System Success**
   - Prevent unsafe or non-compliant merges (Pull Request Guard).
   - Stop unsafe prompts or outputs from executing (Prompt Guard).
   - Prevent runaway LLM costs (Cost Guard).
   - Detect and respond to anomalies cluster-wide before incidents (Wide Guard).


# Ingest (External Data Collection)

- **Telegram Integration** – n8n Telegram nodes configured for chat message ingest and command triggers; messages stored or transformed for agent context.  
- **Social Network Aggregation Tool** – open-source option such as RSSHub, Apprise, or ActivePieces to unify multiple social network feeds (Twitter/X, Mastodon, LinkedIn, Reddit, etc.) into one ingest stream.  
- **MCP Connectors** – n8n nodes for MCP Calendar, MCP Mail, and MCP Business; sync events, emails, and reviews into Graph Memory as typed entities.  
- **Content Normalisation Flow** – triggered via webhook; converts raw ingest data into schema.org-typed nodes and relationships before insertion into Neo4j.

# Security and Networking

**Network Security** – Cilium leveraging eBPF, WireGuard node-to-node encryption, and Hubble for observability, enforcing network policies across services.

**Identity Security** – Keycloak leading with single sign-on, managing tenants, roles, OAuth2/OIDC tokens, and service credentials.

**Infrastructure Certificates** – cert-manager automating TLS certificates using Google Cloud DNS01 challenges as primary nameservers, with annotations to provision certificates automatically for each gateway on deployment.


# Versioning (Code and Data)

## 1. Repository Versioning
- **Tool:** Git  
- **Purpose:** Single source of truth for configuration, deployments, and workflows.  
- **Principles:**  
  - DRY repository  
  - Hydrated into environments via ArgoCD  
  - Every change tracked for reproducibility

## 2. Prompt Versioning
- **Format:** YAML files  
- **Metadata:** intent, domain, metrics, vector_signature, timestamp  
- **Management & Deployment:**  
  - Managed via Prompt Operations  
  - Deployed via ArgoCD  
- **Principle:** Versioned and auditable; previous versions can be rolled back

## 3. Graph Versioning (Self-Healing)
- **Database:** Neo4j  
- **Schema Tracking:** Versions stored as nodes/properties; major changes exported to Git  
- **Self-Healing:**  
  - Graph detects drift from canonical schema  
  - ArgoCD reconciles and hydrates from Git  
  - Ensures consistent, correct schema automatically
- **Principle:** Schema is versioned, consistent, and self-healing

**Summary:**  
All code, prompts, and graph schemas are version-controlled in a DRY Git repository, automatically deployed via ArgoCD, with the graph schema being self-healing.

Billing (Workflow and REST Integration)

Billing Workflow – n8n automation that tracks usage metrics and triggers billing cycles per tenant.

Billing REST Application – lightweight service exposing REST endpoints for invoice creation, usage retrieval, and webhook callbacks from n8n.

Billing Data Flow – metrics collected from LLM interactions, workflow executions, and tenant activity pushed to Billing REST API → persisted in billing database.

Access and Authentication – integrated through Keycloak for per-tenant security.

Frontend Interaction Model

I know it's typescript XD

# need Vocabulary

1. Repository & Core Setup

You’ll merge your mirror document into your main Git repository.

Integrate a Git MCP (Model Context Protocol) to analyze and vet code before pull requests merge.

This MCP will connect with your browser controller and debugger to manage automated checks and deployment validation.

Cilium will need proper eBPF permissions (CAP_SYS_ADMIN, hostPath mounts, privileged mode) to function fully in your Kubernetes environment.

Your DNS-01 challenge (likely for cert-manager) will be verified and fixed if blocked by Cilium or permissions.

2. Data Processing Architecture

You’ll break the workflow into independent N8n flows, each handling a specific function:

Flow 1 — Schema Detection & Neo4j Ingestion

Starts with a webhook trigger, so it can receive data from any source.

Uses a JavaScript app that:

Detects what kind of data is received.

Selects the appropriate schema (either local or dynamic lookup).

Converts the data into JSON-LD format if needed.

Pushes it into Neo4j using your JSON-LD → Cypher converter script.

This makes the ingestion schema-agnostic — any structured data type can be stored as a graph.

Flow 2 — Google Ingestion (via Google MCP)

Ingests data from Gmail and other Google services using the Google MCP.

Requires a Google Cloud service account and OAuth 2.0 credentials to authorize data flow into N8n.

Once authenticated, it continuously syncs Google data for processing or graph updates.

Flow 3 — Telegram Output / Notifications

Handles communications and notifications via Telegram.

Uses a Telegram node in N8n to send details, updates, or responses to you.

Functions similarly to a webhook so your LLM or flows can send outbound messages directly.

Flow 4 — Dynamic Cypher Query Generator

Listens for requests (via Telegram, webhook, or other channel).

Dynamically generates Cypher queries based on user intent or natural-language input.

Runs the query on Neo4j and sends the results back through the same channel that made the request.

Enables cross-platform querying and flexible data retrieval.

3. Supporting Infrastructure

The LLM (likely integrated through the MCP or N8n) acts as the reasoning layer:

Interprets user queries or data context.

Generates or refines Cypher queries.

Communicates via webhooks or Telegram.

Security & Access Control:

Google Cloud OAuth 2.0 handles secure inbound traffic.

Service account credentials are stored in N8n securely (using environment variables or encrypted credentials).

Cilium and DNS-01 configuration ensure the environment is stable and network-safe.