Sets S - finite set of states (processing nodes). Example: 
{Mine,Hopper,Crusher,StockpileA,StockpileB,Feeder,Transport,Product}
{Mine,Hopper,Crusher,StockpileA,StockpileB,Feeder,Transport,Product}

Σ — finite alphabet of actions (events/transitions). Example: 
{load,move,crush,store,blend,feed,ship}
{load,move,crush,store,blend,feed,ship}.

δ:S×Σ→P(S) — nondeterministic transition function (map a state + action to a set of possible next states).




# ⛏️ Mealy Machine for Mining Process (Cheat Sheet)

## 🤖 Finite State Machines (FSM) Overview

FSMs are **computational models** used in the theory of computation, computer science, and digital circuit design to model processes that proceed through a finite number of distinct stages or **states**.

### Types of FSMs

FSMs are primarily classified by their determinism and their output generation:

| Classification | Type | Output Rule | Determinism |
| :--- | :--- | :--- | :--- |
| **Acceptors** | NFA (Non-deterministic) | None (Accept/Reject only) | Multiple transitions possible for one input. |
| **Acceptors** | DFA (Deterministic) | None (Accept/Reject only) | Exactly one transition for every input. |
| **Transducers** | **Mealy Machine** | **Output depends on Current State AND Input.** | **Deterministic.** |
| **Transducers** | Moore Machine | Output depends ONLY on Current State. | Deterministic. |

---

## Defining the Mealy Machine $M$

The **Mealy Machine** is the chosen model for your mining process because the output (the classification: **Transform, Transfer, Store**) is a result of the **action (input event)** taken within a specific state. The machine is formally defined by the 6-tuple: $M=(Q,\Sigma,\Delta,\delta,\lambda,q_0)$.

### 1. Core Components

| Element | Formal Notation | Description | Example (Mining Process) |
| :--- | :--- | :--- | :--- |
| **States** | $Q$ | The finite set of stages in the process. | $Q=\{\text{Extraction, Crushing, Refining, Stockpile, Shipment}\}$ |
| **Input Alphabet** | $\Sigma$ | The set of possible events/actions that trigger a transition. | $\Sigma=\{\text{Complete, QualityPass, QualityFail, Finished}\}$ |
| **Output Alphabet** | $\Delta$ | The set of possible classifications/outputs generated. | $\Delta=\{\text{Transform, Transfer, Store}\}$ |
| **Initial State** | $q_0$ | The starting point of the process. | $q_0=\text{Extraction}$ |

---

### 2. Modeling the Flow and Branching Logic

This table maps the full process, detailing the state change and the output generated upon each transition.

| Current State ($q$) | Input Event ($\sigma$) | Next State ($q'$) | Output Status ($\lambda(q,\sigma)$) |
| :---: | :---: | :---: | :---: |
| **Extraction (A)** | Complete | Crushing (B) | Transform |
| **Crushing (B)** | QualityPass | Refining (C) | Transfer |
| **Crushing (B)** | QualityFail | Stockpile (D) | Store |
| **Refining (C)** | Finished | Shipment (E) | Transfer |

---

### 3. Formal Transition and Output Functions

The functions $\delta$ and $\lambda$ formally capture the deterministic rules, including the critical branching logic (the split flow from Crushing).

#### A. Transition Function ($\delta:Q\times\Sigma\rightarrow Q$)

The function $\delta$ dictates the **next state ($q'$)** based on the current state ($q$) and input ($\sigma$).

$$
\delta=
\begin{cases}
\text{Crushing} & \text{if } q=\text{Extraction} \text{ and } \sigma=\text{Complete} \\
\text{Refining} & \text{if } q=\text{Crushing} \text{ and } \sigma=\text{QualityPass} \\
\text{Stockpile} & \text{if } q=\text{Crushing} \text{ and } \sigma=\text{QualityFail} \\
\text{Shipment} & \text{if } q=\text{Refining} \text{ and } \sigma=\text{Finished} \\
... & \text{otherwise}
\end{cases}
$$

#### B. Output Function ($\lambda:Q\times\Sigma\rightarrow\Delta$)

The function $\lambda$ dictates the **output status** for that specific transition, based on the current state ($q$) and input ($\sigma$).

$$
\lambda=
\begin{cases}
\text{Transform} & \text{if } q=\text{Extraction} \text{ and } \sigma=\text{Complete} \\
\text{Transfer} & \text{if } q=\text{Crushing} \text{ and } \sigma=\text{QualityPass} \\
\text{Store} & \text{if } q=\text{Crushing} \text{ and } \sigma=\text{QualityFail} \\
\text{Transfer} & \text{if } q=\text{Refining} \text{ and } \sigma=\text{Finished} \\
... & \text{otherwise}
\end{cases}
$$


Definitions, notation, and symbols

Sets / formal objects

S
S — finite set of states (processing nodes). Example: 
{Mine,Hopper,Crusher,StockpileA,StockpileB,Feeder,Transport,Product}
{Mine,Hopper,Crusher,StockpileA,StockpileB,Feeder,Transport,Product}.

Σ
Σ — finite alphabet of actions (events/transitions). Example: 
{load,move,crush,store,blend,feed,ship}
{load,move,crush,store,blend,feed,ship}.

δ:S×Σ→P(S)
δ:S×Σ→P(S) — nondeterministic transition function (map a state + action to a set of possible next states).

s0∈S
s
0
	​

∈S — initial state (e.g., Mine).

F⊆S
F⊆S — accepting states (e.g., Product, Shipped or any completion states).

Variables: 
m
m = mass (tons), 
g
g = grade (e.g., % metal), 
w
w = moisture, 
c
c = capacity (tons), 
t
t = time.

Predicates (examples):

Ore(x)
Ore(x) — 
x
x is ore.

Mass(x)=m
Mass(x)=m.

Grade(x)≥g0
Grade(x)≥g
0
	​

.

Capacity(n)≥c
Capacity(n)≥c.

Stock(n,t)=s
Stock(n,t)=s — stock level of node 
n
n at time 
t
t equals 
s
s.

RouteAllowed(u,v)
RouteAllowed(u,v).

Functions:

blend(A,B)
blend(A,B) — blending function, returns blended grade/mass.

crush(x)
crush(x) — returns particle size class.

Logical languages used

Propositional logic: used for boolean conditions (e.g., StockpileFull, FeedOn).

First-order logic (FOL): used for quantification over batches/tons/time (e.g., 
∃
∃ batch with grade ≥ threshold).

Temporal predicates (optional): 
Before(t1,t2)
Before(t
1
	​

,t
2
	​

), 
Within(t,Δ)
Within(t,Δ) for time constraints.

Algebraic constraints: linear inequalities on mass/grade/capacity.

Proof / reasoning styles you may choose

Inductive reasoning (weak/structural): show property holds for initial and preserved under transitions — good for invariants (e.g., mass conservation).

Strong induction: if you need to argue about sequences of operations/aggregates across multiple cycles.

Deductive (axiomatic) rules: exact algebraic derivations (e.g., blending formula).

Model checking style (state exploration): enumerate reachable states to verify safety/acceptance.

How to read the table I will produce for you

Columns (exact layout you requested, each row = one transition entry):

From → To — combined node pair (short).

Payload / Data — what's passed (mass, batch IDs, grade, moisture, container id, timestamps, capacity states). Keep types and units.

Action Type (Σ) — which alphabet symbol(s) trigger the transition (e.g., load, move, crush); list multiple if applicable.

Transition Rules (logic) — one or more rule lines (propositional + FOL) that must hold to enable the transition. Use ∨ for alternatives, ∧ for conjunction, quantifiers where needed. Nondeterminism is made explicit by multiple rules leading to same/different next states.

Reasoning / Proof method — what logical rigor we adopt to justify/verify this rule (e.g., invariant by weak induction, arithmetic proof, existence proof via ∃, decision procedure using SMT-like linear arithmetic, or model checking).

Example: table template + filled example (ore-processing use case)

Below I provide a table first showing the empty template row format, then a concrete example with several sample transitions. Treat this as the canonical template I will use when you send your document; I’ll fill S, Σ, and δ formally from your text.

Template (one-row example)
From → To	Payload / Data	Action Type (Σ)	Transition Rules (logical)	Reasoning / Proof method
A → B	(mass 
m
m in t, grade 
g
g in %, batchID, time 
t
t)	e.g. move / store	1. 
m>0∧Capacity(B)≥m
m>0∧Capacity(B)≥m 2. 
∃b. Batch(b)∧Grade(b)≥gmin
∃b. Batch(b)∧Grade(b)≥g
min
	​

	Weak induction to show invariant total_mass preserved; arithmetic constraints proven deductively.