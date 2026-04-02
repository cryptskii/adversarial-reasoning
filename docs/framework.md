# Adversarial Assumption Reasoning — Framework Reference

## Core Principle

Truth is often identified not only by what supports it, but by what survives
systematic attempts to falsify it.

This framework treats reasoning as a structured adversarial loop between:

- A **Negative Analyst** that identifies assumptions, contradictions, missing
  constraints, and failure patterns
- A **Positive Constructor** that builds the strongest valid solution and explains
  how it differs from nearby false paths
- An **Independent Critic** (external model) that attacks the positive candidate
  with different blind spots than the builder

The system should never treat incorrect answers as merely "not correct."
It must understand *why* they fail.

## Roles

### Negative Analyst

Responsible for attacking candidate reasoning. Must:

- Identify explicit and hidden assumptions
- Detect contradiction chains
- Identify missing constraints
- Search for category errors
- Detect equivocation or definition drift
- Find edge cases and boundary conditions
- Generate counterexamples where possible
- **Classify the failure type** (typed criticism, never vague)

### Positive Constructor

Responsible for building the strongest valid candidate. Must:

- State the target claim precisely
- Use only justified assumptions
- Preserve relevant constraints
- Show the minimal chain of valid reasoning
- Distinguish the valid path from nearby invalid ones
- Explain why the valid reasoning survives criticisms raised against failed candidates
- Produce a **contrastive explanation**: why this works, why rejected paths fail,
  what assumptions make the difference

### Independent Critic (Cross-Model)

Responsible for structurally independent verification. Must:

- Come from a different model/vendor than the builder
- Attack the positive candidate with typed failure labels
- Identify hidden assumptions the builder missed
- Test edge cases the builder didn't consider
- Return a structured verdict (survives / damaged / fatal)

## Failure Label Taxonomy

| Label | Meaning |
|-------|---------|
| `false_premise` | Starting assumption is factually wrong |
| `unsupported_assumption` | Assumption present but unjustified |
| `invalid_inference` | Conclusion doesn't follow from premises |
| `missing_constraint` | Important condition not accounted for |
| `boundary_condition_failure` | Breaks at edge cases |
| `contradiction_with_known_facts` | Conflicts with established knowledge |
| `internal_inconsistency` | Reasoning contradicts itself |
| `category_error` | Mixes incompatible types or levels of analysis |
| `equivocation` | Key term shifts meaning between steps |
| `overgeneralization` | Conclusion broader than evidence supports |
| `underspecified_claim` | Too vague to evaluate or falsify |
| `solves_adjacent_problem` | Answers a different question than asked |
| `locally_valid_globally_invalid` | Each step fine, whole argument broken |
| `circular_reasoning` | Conclusion assumed in premises |
| `non_falsifiable` | Claim cannot be tested or disproven |
| `conclusion_too_strong` | Evidence supports only a weaker version |

## Intervention Protocol

| Verdict | Meaning | Action |
|---------|---------|--------|
| `survives` | Reasoning withstood adversarial attack | Proceed to final answer |
| `damaged` | Serious issues found but potentially fixable | Repair specific issues, re-critique if needed |
| `fatal` | Fundamental structural flaw | Return to construction, rebuild from scratch |

## Behavioral Rules

1. Never accept first-plausible-answer syndrome
2. Criticism must be typed — no vague "this seems wrong"
3. Final answer must be contrastive — why right relative to nearby wrong
4. Rhetoric is not evidence — elegant prose is not a substitute for validity
5. Candidate sets must be disciplined — plausible, not exhaustive
6. Ambiguity surfaces early — before analysis, not after
7. Conclusion matches support — never claim certainty from plausibility
8. Independent critique is real input — engage substantively
9. Distinguish fatal vs repairable failures
10. Never merge incompatible frameworks silently

## Success Criteria

The system is succeeding when it:

- Catches hidden assumptions before they contaminate the answer
- Distinguishes persuasive wrong answers from valid ones
- Explains *why* alternatives fail, not just that they do
- Produces answers that are narrower but more defensible
- Degrades gracefully into uncertainty instead of hallucinated certainty

## Failure Modes to Watch

- Performative critique with no actual logical bite
- Flooding with too many low-value candidates
- Mislabeled failures
- Mistaking skepticism for rigor
- Over-pruning genuinely valid but unusual answers
- Circular confirmation (builder and critic share blind spots) — **this is what cross-model critique solves**
- False precision in confidence statements
