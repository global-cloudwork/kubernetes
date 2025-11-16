# Global Cloudwork Platform — Project Summary

## Executive Summary
Global Cloudwork is a hybrid Kubernetes-based platform offering an affordable, globally distributed “all-in-one” microservices stack. It combines on-premises compute with lightweight cloud gateways to deliver ERP, CRM, AI hosting, database, workflow automation, and graph-based knowledge services. Core features include zero-trust networking with Cilium/eBPF, GitOps deployments via Argo CD, stateful processing in Neo4j, and automated orchestration in n8n.

## Goals and Scope
- Provide end-to-end microservice hosting (ERPNext, Keycloak, OpenWebUI, etc.)
- Enable low-latency global access via Cilium gateway mesh and WireGuard VPN
- Support hybrid on-prem/cloud infrastructure to minimize cost
- Deliver AI-driven workflow automation and process analytics
- Ensure high availability, disaster recovery, and compliance readiness

## System Overview
### Core Components
- **RKE2**: Kubernetes distribution  
- **Cilium & eBPF**: Zero-trust pod/node networking, encryption, policy enforcement  
- **WireGuard**: Secure mesh VPN for on-prem node integration  
- **Argo CD**: GitOps control plane for automated, just-in-time deployments  
- **n8n**: Workflow orchestrator (think-act-feel automation loops)  
- **Neo4j**: Graph database for schema-based knowledge storage  
- **Longhorn**: Distributed block storage for HA volumes  
- **Keycloak**: Single sign-on and identity management  
- **Cert-Manager**: TLS certificate issuance and renewal  

## Tenancy & Isolation
- Each tenant receives an isolated Git repo, Google Cloud account, service accounts, and secrets  
- Dedicated WireGuard mesh for confidential on-prem connections  
- Cilium network policies enforce strict segmentation between tenants  

## Data & Storage Architecture
- **Neo4j** stores parsed schema.org entities as a contextual knowledge graph  
- **Longhorn** replicates block storage across nodes for resilience  
- Cloud storage (GCP buckets) handles large model artifacts and backups  
- Future caching layer (Redis) for high-throughput workloads  

## Networking & Security Model
- External ingress TLS terminated at cloud gateway pods  
- Pod-to-pod and node-to-node encryption via Cilium/eBPF and NodeTrust  
- Google VPC firewall rules block unauthorized IPs before gateway  
- Secrets managed in Google Secret Manager, accessed at runtime by service accounts  
- Hubble for network visibility, Cilium policies for micro-segmentation  

## Deployment & GitOps Strategy
- Single monorepo with “next” (staging) and “live” branches per environment (dev, test, prod)  
- Helm charts + manifest hydration drive reproducible deployments  
- Argo CD continuously reconciles desired state across multi-cluster mesh  
- Canary, rolling, and fault-tolerant update patterns baked into pipelines  

## Observability, Monitoring & SLAs
- Planned stack: Prometheus (metrics), Grafana (dashboards), Loki (logs) or Datadog managed service  
- n8n health checks every 10 min; Argo CD alerts via LLM‐driven summaries to e-mail/SMS  
- Entry-level SLAs: 99.5% uptime, MTTR targets, max latency thresholds, backup/recovery windows  

## Disaster Recovery & Backups
- Triple-redundant backups across on-prem, GCP, and AWS  
- Argo CD bootstrapping enables full cluster rebuild from Git + secrets  
- Multi-cloud gateway failover between GCP primary and AWS secondary  

## Onboarding & Tenant Lifecycle
1. Provision tenant GitHub repo and GCP account  
2. Initialize service accounts, secrets, and env files  
3. Deploy gateway pod and distribute WireGuard config  
4. Run bootstrap script to join on-prem nodes automatically  

## Performance, Cost & Efficiency
- East-west scaling with ephemeral micro-nodes to reduce cloud spend  
- Heavy compute offloaded to on-prem hardware; small regional pods handle ingress  
- Future Monte Carlo simulations on Mealy-machine state data for workload prediction  

## Risks & Mitigations
- **Crawler orchestration complexity**: centralized heartbeat tracker pod, sharded pods  
- **Neo4j scaling**: subgraph sharding, batched writes, indexing critical relationships  
- **Incomplete documentation**: periodic scavenger bot in think-act-feel loops  
- **Simulation cost**: scheduled batch jobs, resource-aware queue management  
- **Parsing errors**: validation workflows, schema metadata versioning  

## Roadmap & Next Steps
- Finalize observability stack and implement SLIs/SLOs  
- Build n8n flows: data ingest, schema selection, PDF-to-rules, Mealy math, Monte Carlo, documentation  
- Draft architecture diagrams (see documentation/diagrams.md)  
- Perform large-scale simulation tests and cost benchmarking  
- Prepare compliance audit (PIPEDA, ISO 27001)  

## References & Glossary
- **Cilium/eBPF**: Kernel-level networking and security  
- **Mealy Machine**: State machine model with output on transitions  
- **GitOps**: Declarative infrastructure via Git authoring  
- **Zero Trust**: Security model denying implicit trust between workloads  
- See `documentation/operational-lexicon.md` for full term definitions
