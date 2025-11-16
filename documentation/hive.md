```markdown
# Hive Mind Architecture — High-Level Overview

A hive-inspired, distributed cognitive system where ephemeral agents (“bees”) traverse task workflows (finite state machines), converting raw data into refined knowledge and driving scalable, decoupled processing. Communication and coordination rely on scent trails (SENT) and hierarchical heartbeats, under the macro-management of a central Queen.

---

## 1) SENT (Scent) Signaling  
- **Pheromone-like trails**: Bees drop SENT markers on flow nodes to denote success, failure, anomaly, or priority.  
- **Layers of propagation**:  
  - *Local*: nearby bees adjust behavior based on intensity.  
  - *Subspace*: all bees in a task flow receive moderate signals.  
  - *Global (echolocation)*: broadcast summaries (e.g., “heartbeat anomaly”) across the hive.  
- **Payload**: location (flow node/subspace), type (success, failure, alert, anomaly), strength, timestamp, optional task ID.

---

## 2) Bee Roles  
- **Forager Bees**  
  - Gather raw inputs (pollen) from external sources.  
  - Report high-value or hazardous sources via SENT.  
- **Worker Bees**  
  - Run two FSMs in tandem (see below).  
  - Execute domain-specific tasks, transform data into knowledge (honey).  
  - Leave SENT based on outcomes.  
- **Nurse Bees**  
  - Incubate and prime larvae with flowcharts, tables, and context.  
  - Select which larvae mature into active workers.  
- **Manager Bees**  
  - Decompose high-level tasks, allocate workers and nurses.  
  - Monitor sub-bees via heartbeats and SENT; request scaling.  
- **Security (Autonomous) Bees**  
  - Operate off-loop for independent anomaly detection and investigation.  
  - Persist longer and quarantine failing flows when needed.  
- **Drones/Analytic Bees**  
  - Perform Monte Carlo simulations, predictive modeling, and flow optimization.  
- **Queen**  
  - Central coordinator of population, type ratios, and hive health.  
  - Makes macro decisions based on aggregated SENT and heartbeats.

---

## 3) Dual-FSM Model per Bee  
1. **Domain-Loop FSM**  
   - Continuously navigates its functional area (e.g., perception, memory, planning).  
   - Maintains local state and exploration context.  
2. **Task-Definition FSM**  
   - Encodes the specific workflow for the current task (e.g., parse business logic, run sub-flow).  
   - Drives concrete actions toward task completion.  
**Interaction**: Both FSMs run concurrently. If a bee terminates, a new bee is spawned with preserved domain context and task parameters.

---

## 4) Thematic Domains  
- **Perception & Ingestion**: data collection, pre-processing.  
- **Memory & Knowledge**: context storage, recall, knowledge graph updates.  
- **Planning & Decision**: reasoning, hypothesis testing, speculative execution.  
- **Execution & Transformation**: concrete task steps and data manipulation.  
- **Security & Resilience**: anomaly detection, isolation, independent monitoring.  
- **Analytics & Optimization**: predictive insights, flow refinement via SENT patterns.  
- **Governance & Health**: population balance, throughput, latency, and type distribution.

---

## 5) Structure & Lifecycle Overview  
1. **Queen** spawns **Manager** bees.  
2. Managers request **Nurse** bees when scaling tasks—nurses incubate **Larvae**.  
3. Larvae mature into **Worker** bees, primed with domain and task FSMs.  
4. Workers traverse flows, execute tasks, and drop SENT.  
5. **Security** bees monitor off-loop; **Drones** run analytics.  
6. Heartbeats and SENT feedback guide Queen’s macro decisions and resource reallocation.

---

*This summary is designed for executive and stakeholder briefings to convey the high-level hive mind architecture, roles, and core mechanisms without code details.*  
```