# HiveMind Bee — Formal Project Specification

## Overview
The HiveMind Bee is an autonomous agent driven by a six-state cognitive loop—**Perceive**, **Interpret**, **Evaluate**, **Plan**, **Act**, **Reflect**—designed to execute complex tasks via iterative reasoning. It combines:
- A **memory model** with long-term storage and a limited rolling short-term window that decays to prevent context pollution.
- A **pheromone-based directed graph** that biases state transitions and subgraph traversals, reinforced by successes and decayed over time.
- **Nested deterministic subgraphs** (N8N flows) for concrete tool operations, invoked through an MCP interface.
- **Lifecycle management** (larva → nurse → worker → death) with permissioned access and safety gates.

## Objective
Provide a reusable, extensible architecture for autonomous task execution. Each Bee instance is primed with an initial goal, permissions, and a toolkit, and then loops until completion or expiration.

## Scope
**In-Scope**
- Six-state loop orchestration (Perceive → Interpret → Evaluate → Plan → Act → Reflect).
- Long-term memory (LTM) for persistent knowledge and pheromone trails.
- Short-term memory (STM) as a rolling window with automatic decay.
- Pheromone mechanics on edges to bias probabilistic traversal.
- Nested, deterministic subgraphs implemented as N8N workflows.
- Unit decomposition via similarity search in the Interpret phase.
- MCP interface for Plan/Act tool invocations.
- Lifecycle stages with controlled spawn, approval, maturation, and termination.

**Out-of-Scope**
- UI/UX design and platform-specific runtime details.
- Comprehensive security policies beyond basic permission gating.

## System Architecture Overview
1. **Cognitive Loop**  
   Perceive → Interpret → Evaluate → Plan → Act → Reflect, repeated until TTL expires or task completes.

2. **Memory Model**  
   - **LTM**: Persistent knowledge store, pheromone graphs, policy templates.  
   - **STM**: Limited history of recent steps (e.g., two-step window), pruned each cycle.  
   - **Decay**: Both STM entries and pheromone weights drift to defined baselines over time.

3. **Pheromone Graph**  
   - Weighted directed edges represent state transitions and subgraph links.  
   - **Reinforcement**: Successful cycles add to edge weights.  
   - **Decay**: All weights trend toward baseline absent reinforcement.  
   - **Exploration**: Stochastic traversal biased by pheromones avoids local maxima.

4. **Subgraphs (N8N Flows)**  
   - Deterministic workflows triggered by Plan or Perceive.  
   - Hierarchical nesting supports layered capabilities (larva → worker).  
   - Defined interfaces map planner decisions to tool invocations.

5. **Task Representation**  
   - **Interpret** decomposes tasks into atomic unit nodes.  
   - Similarity search against a knowledge base assigns initial weights.  
   - Clustering emergent patterns informs traversal biases.

6. **Planning & Execution**  
   - **Plan** selects next action/subgraph via Evaluate results and STM.  
   - **Act** invokes MCP tools, captures outcomes.  
   - **Reflect** updates LTM, pheromone trails, prunes memory, adjusts policies.

7. **Lifecycle & Governance**  
   - **Spawn**: Larva created with priming context.  
   - **Nurse**: Approval gate for viability.  
   - **Worker**: Full operational phase with expanded toolkit.  
   - **Death**: TTL expiration or absorbing failure conditions.

## Conceptual Data Model
- **BeeInstance**: id, ttl, ltm, stm, pheromoneGraph, subgraphs, permissions, status, log.
- **SubgraphDescriptor**: id, type, steps, edgeWeights, constraints.
- **UnitNode**: id, features, weight, mandatory.
- **PlanAction**: actionType, payload.
- **MemoryDecayRules**: schedule, baselineWeights.
- **KnowledgeBase**: entries, pheromoneTrails.
- **Permissions**: roles, allowedTools, restrictedKnowledge.

## Behavioral Semantics (Atomic Rules)
- **Perceive**: Ingest inputs, reference primed subgraphs, update STM.  
- **Interpret**: Decompose tasks into units, perform similarity search, assign weights.  
- **Evaluate**: Score candidate paths by pheromones, unit weights, resource availability.  
- **Plan**: Choose next step/subgraph, ingest live inputs, refine short-term plan.  
- **Act**: Execute chosen action via MCP, record outcomes.  
- **Reflect**: Reinforce or decay pheromones, update LTM, prune STM, adjust future policies.

## Algorithmic Highlights
- **Pheromone Update**: +1 on successful edges; global decay toward baseline.  
- **Memory Management**: STM window limit and selective pruning; LTM aging.  
- **Similarity Search**: Unit-level retrieval for initial weighting and clustering.  
- **Subgraph Traversal**: Deterministic N8N flow invocation for concrete tasks.

## Milestones & Deliverables
- Milestone 1: Define data schemas (BeeInstance, SubgraphDescriptor, UnitNode, PlanAction).  
- Milestone 2: Draft deterministic subgraph templates for common tasks.  
- Milestone 3: Implement basic pheromone graph with decay rules.  
- Milestone 4: Wire Plan/Act to MCP calls; build minimal prototype.  
- Milestone 5: End-to-end demonstration with logging and Reflect analysis.

## Acceptance Criteria
- A documented specification capturing all architecture layers.  
- A minimal prototype demonstrating a few loops, pheromone updates, and subgraph invocation.  
- Logs showing Reflect updates and controlled termination.

## Next Steps
1. Define concrete JSON Schema or protobuf for data models.  
2. Create base N8N subgraph templates.  
3. Implement pheromone graph library with reinforcement and decay.  
4. Build test harness for cognitive loop.  
5. Review and iterate on documentation with stakeholders.
