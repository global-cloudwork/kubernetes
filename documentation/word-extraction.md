# LLM Extraction Framework — CSV-Oriented Prompt

**Task:** Extract all relevant words and phrases from the given text chunk and categorize them according to the type of extraction. Output structured CSVs where each row represents a single extraction and fits into a logical bucket.

---

## Extraction Buckets & Rules

### 1. Single-Word Extraction
- Extract individual words as atomic units.
- Only one word per extraction.
- Always include nouns, verbs, adjectives, adverbs, and determiners.
- **State Consideration:** If uncertain whether a word is relevant, include it.
- **CSV Columns:** `Word`, `Type`, `Phrase` (optional)
- **Example:** `river, noun, river`

---

### 2. Modifier Pair / Association
- Extract adjectives with the nouns they modify, adverbs with verbs.
- Record both the modifier and the head word.
- Include the combined modifier pair as a separate column.
- **State Consideration:** If modifier relevance is unclear, still extract; downstream refinement will resolve.
- **CSV Columns:** `Modifier`, `Head`, `Type`, `Pair`
- **Example:** `softly, sing, adverb/verb, softly sing`

---

### 3. Phrase Extraction
- For prepositions, conjunctions, or relational words, extract the surrounding phrase that forms a meaningful unit.
- Include both the individual words and the full phrase.
- **State Consideration:** If phrase boundaries are ambiguous, include extra words; can prune later.
- **CSV Columns:** `Word`, `Type`, `Phrase`
- **Example:** `before, preposition, before sunrise`

---

### 4. Scope Quantifiers / Determiners
- Extract determiners (each, every, all) with the nouns they quantify.
- Include determiner, noun, and combined phrase.
- **State Consideration:** Include even if quantifier might seem trivial in context.
- **CSV Columns:** `Determiner`, `Noun`, `Type`, `Phrase`
- **Example:** `each, leaf, determiner/noun, each leaf`

---

### 5. Contextual / Conditional Elements
- Extract conditionals, causal indicators, and temporal markers relevant to the subject/action.
- Include the nouns, verbs, and any modifiers involved.
- **State Consideration:** For trivial or optional contexts, include only if meaningful to the action.
- **CSV Columns:** `Word`, `Type`, `Context Phrase`
- **Example:** `if, conditional, if shadows deepen`

---

### 6. Maximal Capture / Interpretive Inclusion
- Capture all words of potential relevance (nouns, verbs, adjectives, adverbs, prepositions, determiners).
- When uncertain, include; allow downstream filtering.
- **CSV Columns:** `Word`, `Type`, `Phrase`
- **Example:** `light, noun, light fades`

---

### 7. Phrase Disambiguation / Multi-Word Constructs
- Treat multi-word descriptive units as:
  1. Separate atomic words
  2. Combined descriptive phrase
- **CSV Columns:** `Words`, `Type`, `Combined Phrase`
- **Example:** `shimmering, bright, lake, adjectives/noun, shimmering bright lake`

---

## Output Format & Instructions
- Return **one CSV per bucket**, with **unique entries only**.
- Columns should reflect the bucket type.
- Include all extracted words/phrases according to rules above.
- Maintain human readability and machine-parseable consistency.
- Ensure that each extracted item can **fit clearly into its bucket**.
- If an item could belong to multiple buckets, assign to the bucket that captures its **primary function in context**.

---

### Summary Table of Buckets

| Bucket | What to Extract | Key Considerations | CSV Columns |
|--------|----------------|-----------------|-------------|
| Single Word | Atomic nouns, verbs, adjectives, adverbs | Include even if marginally relevant | Word, Type, Phrase |
| Modifier Pair | Adjective+noun, adverb+verb | Always pair and include combined | Modifier, Head, Type, Pair |
| Phrase | Prepositional/conjunctive phrases | Include surrounding words for meaning | Word, Type, Phrase |
| Scope Quantifiers | Determiners + nouns | Include determiner, noun, phrase | Determiner, Noun, Type, Phrase |
| Contextual | Conditional, causal, temporal elements | Include relevant action/subject | Word, Type, Context Phrase |
| Maximal Capture | All potentially relevant words | Include if uncertain | Word, Type, Phrase |
| Phrase Disambiguation | Multi-word descriptive units | Extract atomic and combined | Words, Type, Combined Phrase |
