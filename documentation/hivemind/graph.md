# Pheromone-Guided Traversal Graph

This document outlines the rationale, structure, and construction process for a persistent, pheromone-reinforced graph that agents (bees) traverse to accomplish tasks. It covers graph topology, pheromone channels, node and edge design, and growth rules.

---

## 1. Purpose

- Provide a shared environment where multiple agents explore workflows, leave signals, and converge on optimal paths through emergent behavior.
- Support minimal initial scaffolding that grows organically as agents propose new connections and reinforce successful routes.
- Balance exploration (discover new edges) and exploitation (follow high-value paths) via dynamic pheromone levels.

## 2. Graph Structure

- **Nodes** represent atomic, deterministic operations or states (e.g., “parse CSV,” “validate schema,” “save to DB”).
- **Edges** define permitted transitions between operations. Initially, only core edges exist; additional edges are added by agent proposals.
- A single start node anchors each process map; completion nodes have no or only terminal exits.

## 3. Pheromone Channels

Implement multiple pheromone properties on nodes and edges:
- **pheromone_success**: reinforced when an agent completes a sub-goal along this path.
- **pheromone_fail**: reinforced when an agent encounters a dead end or failure here.
- **pheromone_explore**: optional, tracks pure exploration activity.

## 4. Pheromone Dynamics

1. **Reinforcement**  
   - On success, increase `pheromone_success` on every traversed edge/node.  
   - On failure or loop, increase `pheromone_fail`.

2. **Evaporation**  
   - Periodically decay all pheromones by a factor (e.g., multiply by 0.9) to avoid stale dominance.

3. **Diffusion (Optional)**  
   - Spread a portion of pheromone to neighboring edges to encourage nearby exploration.

## 5. Traversal Decision Logic

During each agent’s evaluate/plan phase:
1. Read outgoing edges’ pheromone values.
2. Calculate weighted probabilities:
   - Favor high `pheromone_success`.  
   - Penalize high `pheromone_fail`.  
   - Include a small chance to follow low-pheromone edges (exploration).
3. Select next edge and perform the associated node action.

## 6. Graph Seeding & Growth

1. **Seed Scaffold**  
   - Populate graph with minimal, high-level nodes and core transitions for the most common workflows.

2. **Proposal Mechanism**  
   - If an agent needs a transition not yet in the graph, it writes a proposal marker on the source node.
   - A validator (queen module or human reviewer) checks and approves valid proposals.
   - Approved edges are added with low initial pheromone to be explored.

## 7. Node and Edge Definitions

- Node definitions must be highly specific:  
  - Inputs, outputs, preconditions, and postconditions are clearly declared.
- Edges carry transition rules, permissions, and optional context labels (e.g., “requires-auth,” “batch-mode”).

## 8. Roles & Safety Controls

- **Explorer Agents** focus on low-pheromone edges and make new-edge proposals.  
- **Worker Agents** exploit high-success paths for reliable task execution.  
- **Validator Agents** review proposals, prune invalid edges, and adjust pheromone to prevent runaway loops.

Safety measures:
- Cap maximum pheromone per edge to prevent monopolies.
- Enforce loop-detection thresholds; penalize looping agents heavily.
- Limit new proposals per cycle until core graph stabilizes.

---

**Outcome:**  
A self-organizing, pheromone-guided graph that begins with a small seed, grows via proposals, and optimizes over time as agents explore, reinforce, and refine workflows. This design supports emergent multi-agent coordination without centralized micromanagement.
