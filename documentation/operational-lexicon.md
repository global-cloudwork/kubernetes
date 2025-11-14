State-based decision machine (theory-crafted) — uses only logical statements + LLM queries

Nice — here’s a complete, rigorous design for a state-based decision-making machine that only represents knowledge as logical statements and treats LLMs as external oracles it queries to obtain truth assignments, derived facts, or explanations. The design covers formal state definitions, transition guards written as logical predicates, how to build and parse LLM queries so responses become logic, consistency & verification, auditability, and pragmatic prompt templates. I include pseudocode, example workflows, and failure-mitigation strategies.

Core idea (one-sentence)

Keep machine state as a set of logical formulas; transitions are triggered by logical predicates over that set; when the machine needs additional facts or derivations it issues constrained queries to one or more LLMs, then ingests only logically-expressible answers (atoms, implications, or structured proof steps) and uses logic-based checks (entailment/consistency) to continue.

Notation & primitives (pure logic)

Σ — current knowledge base (KB): a finite set of logical formulas in first-order / propositional style (no fuzzy truth values).

Atomic formulas: P(a), R(x,y), Done(task), RiskHigh(asset).

Logical connectives: ∧, ∨, →, ↔, ¬.

Quantifiers: ∀, ∃, ∃! (when using predicate logic).

K_LLM(m, t, r) — metadata predicate saying “model m at time t returned result r” (for provenance).

Entails(Σ, φ) — semantic entailment check (Σ ⊨ φ).

Derivable(Σ, φ) — syntactic derivability (Σ ⊢ φ) via chosen proof system.

Consistent(Σ) — returns true iff Σ is not contradictory.

Boolean response set from oracle: {TRUE, FALSE, UNKNOWN} mapped to logic as:

TRUE → add φ to Σ (or add □φ depending on policy)

FALSE → add ¬φ to Σ

UNKNOWN → add ¬(φ) ? — better: add Unknown(φ) and leave for verification

For epistemic bookkeeping we can use epistemic operator K or simply keep Bel(m, φ) / Assert(m, φ) for “LLM m asserted φ”.

States (finite set S)

Idle — waiting for a decision request.

Formulate — convert request into formal logical goals & constraints.

Gather — collect local facts, sensors, databases; add to Σ.

QueryLLM — create constrained logical query for LLM(s); issue query.

Ingest — parse LLM response into logical formulas and provenance metadata; tentatively add to Σ.

Evaluate — perform entailment, derive consequences and candidate actions.

Verify — run consistency checks, cross-LLM comparison, counterfactual probing; possibly ask follow-up LLM queries.

Decide — apply decision policy to choose action(s) purely from Σ and derived consequences.

Explain — produce an explanation of the decision as a sequence of logical derivations.

Archive — record final Σ, action, provenance into audit log.

Error/Retry — handle contradictions, malformed LLM output, or failure to decide.

Transition function δ : S × Events → S (guarded by logical predicates)

We'll describe key transitions and their guards as logic predicates over Σ and inputs.

Idle → Formulate

Trigger: Request(goal) arrives.

Guard: True (always allowed).

Action: produce Goal(goal) and Constraints(c₁, c₂, ...) and add to Σ.

Formulate → Gather

Guard: Goal(goal) ∈ Σ ∧ ¬GatheredFacts(goal)

Action: produce queries to local DBs/sensors; add facts F to Σ.

Gather → QueryLLM

Guard: Goal(goal) ∈ Σ ∧ NeedOracle(goal, Σ)
(e.g., ¬Entails(Σ, goal) ∧ there exists φ s.t. external knowledge required)

Action: build constrained logical queries Q and send to selected LLM(s).

QueryLLM → Ingest

Guard: LLMResponse(raw) received.

Action: parse raw → structured claims C = {φ₁, φ₂, ...} plus provenance; temporarily add as Tentative(C).

Ingest → Evaluate

Guard: Tentative(C) ≠ ∅

Action: add C to Σ with provenance tags; run immediate derivations.

Evaluate → Verify

Guard: DecisionCandidates ≠ ∅ ∧ (¬Consistent(Σ) ∨ SomeCandidate is underspecified)

Action: mark candidates, prepare verification probes.

Verify → QueryLLM (loop)

Guard: VerificationNeeded(Σ)

Action: issue follow-up queries (contradiction resolution, provenance check, counterexamples).

Verify → Decide

Guard: Consistent(Σ) ∧ DecisionPolicyApplies(Σ)

Action: compute action(s) A from Σ.

Decide → Explain

Guard: Action A selected

Action: derive proof sequence Proof(A) showing Σ ⊢ A.

Explain → Archive

Guard: explanation generated

Action: store Σ, Proof(A), all LLM provenance, timestamps.

any-state → Error/Retry

Guard: parsing failure, LLM returned out-of-spec format, fatal contradiction, or timeouts.

Action: rollback tentative updates or mark Unknown(φ) and attempt limited retries with stricter prompts.

Formal transition guard examples (written as predicates)

NeedOracle(goal, Σ) := ¬Entails(Σ, goal) ∧ ∃ψ ∈ Ontology s.t. ψ references external world or ungrounded constant.

VerificationNeeded(Σ) := ∃φ such that Bel(m, φ) ∈ Σ ∧ ∃¬φ or ¬Consistent({φ} ∪ Σ')

DecisionPolicyApplies(Σ) := ∃A (Σ ⊢ Preconditions(A) ∧ ¬Σ ⊢ ¬Preconditions(A))

How LLMs are used (oracle contract)

Treat LLMs as oracles that must return strictly-structured logical content. The machine:

Sends a constrained prompt that:

Requires the LLM to output only JSON containing:

claims: list of atomic formulas or implications (strings in a pre-agreed syntax).

justification: list of proof-steps (preferably each step as an implication or known rule).

confidence (optional): non-logical numeric field for human review only — must not be used as a truth value in logic.

Insists: “Do not include chain-of-thought or extra prose. Output must be parseable JSON with claims as logical formulas only.”

Parses the JSON into logical formulas. If parsing fails → go to Error/Retry.

Maps LLM claims into KB:

If claim is φ → add Assert(m, φ) and (policy option) φ (if model trusted).

If claim is φ → ψ → add implication formula.

If claim is Unknown → add Unknown(φ).

Provenance: always attach K_LLM(m, t, raw) and the model identifier.

Example of allowed claim syntax:
Human(Socrates), Mortal(x), ∃x Friend(x,Alice), Price(item1) > Price(item2), PurseLoss → HighRisk.

Prompt template (constrained, minimal)

SYSTEM: You are an oracle for a logic system. Output must be valid JSON with exactly fields claims (array of formulas), justification (array of steps), source (string id). Use only the logical syntax defined (atoms, ∧, ∨, →, ¬, ∀, ∃). No prose. If you cannot decide, return {"claims":["UNKNOWN"], "justification":[], "source":"<id>"}.
USER: Given premises: [ ... list of premises ... ]. Answer the query: φ (a single target formula). Produce claims that include whether φ is true, false, or unknown, and any intermediate atomic facts or rules used to support that answer. Provide minimal justifications as logical steps.

(Adapt as needed; the machine constructs the premises list from Σ.)

Parsing & ingestion rules

Strict grammar: a small grammar for formulas (e.g., BNF) must be enforced. Reject anything else.

Atomic normalization: canonicalize variable names, predicate names, quantifier placement.

Tentative vs. Committed:

Tentative if only one LLM or if provenance low-trust.

Committed if multiple independent oracles agree or if derived via internal proof.

Consistency, contradiction handling & verification

Immediate consistency check: after adding new claims, evaluate Consistent(Σ). If false, trigger Verify.

Paraconsistent approach: instead of letting one contradiction blow everything up, tag contradictory statements with provenance and suspend derived actions that depend on conflicting atoms. Use paraconsistent logic rules (e.g., prioritize provenance, use timestamp or model trust weight).

Cross-model voting: ask N different LLMs with the same constrained prompt. If majority assert φ, tentatively accept φ (still with provenance).

Counterexample probing: ask the LLM for a counterexample if it asserts a universal claim (∀x P(x) → ask for a sample x making it true, and separately ask another LLM to try to falsify).

SMT/SAT checks: run an external prover (SAT/SMT) on Σ to check entailments (e.g., prove Σ ⊢ goal or Σ ⊬ goal). This keeps the decision purely logical.

Decision policy (purely logical)

Decision selection must follow a logical decision policy expressed as formulas. Example:

SelectAction(a) iff Preconditions(a) ⊆ Σ ∧ ∀b (Preconditions(b) ⊆ Σ → Utility(a) ≥ Utility(b))

But since utilities are numeric (non-logical), keep decision rule as lexicographic logical priorities:

encode priority levels as logical atoms: PriorityHigh(a), PriorityMedium(a).

Decision rule: choose any a such that Preconditions(a) derivable from Σ and ¬∃b (Preconditions(b) derivable ∧ HigherPriority(b,a)).

All comparisons and policies must be expressed in logical terms (priority atoms, preconditions, constraints). If numeric calculations are needed, treat results as externally-derived atomic facts (e.g., Score(A)=7 becomes atom Score_A_7) — i.e., convert numerical info into discrete logical atoms before using in logic to select.

Explainability & proof extraction

Generate Proof(A) as a sequence of formulas φ₁, φ₂, ..., A such that each φᵢ is either in Σ or follows by inference rules from prior φs.

Keep provenance tags on each formula in the proof: φᵢ [AssertedBy=ModelX@time] or φᵢ [Derived].

Explanation output is a structured proof object (not prose), e.g.:

Deductive - Valid (sound / unsound) / Invalid
Inductive - Strong (cogent / not cogent) / Weak 