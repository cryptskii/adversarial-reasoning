---
name: adversarial-reasoning
description: "Structured adversarial reasoning with cross-model critique. Enumerates candidates, extracts assumptions, classifies failures, constructs the strongest valid path, then shells out to independent AI models for Stage 6 attack — breaking circular confirmation between builder and critic."
user-invokable: true
---

# Adversarial Assumption Reasoning

Structured reasoning skill that treats truth as what survives systematic falsification.
Uses an internal Negative Analyst / Positive Constructor loop for Stages 1–5, then
calls **independent AI models via terminal** at Stage 6 for genuinely independent critique.

## Why Cross-Model Critique

The fundamental weakness of single-model adversarial reasoning is circular confirmation:
the critic shares the builder's blind spots, training biases, and failure modes. When
a model attacks its own reasoning, it tends to find the flaws it would predict —
not the ones it is blind to.

Independent models at Stage 6 fix this. Different model, different training, different
blind spots. The critique is structurally independent.

## When to Use

- Subtle logical reasoning with competing interpretations
- Ambiguous or underconstrained problems
- Claims that need adversarial vetting before acceptance
- Debugging where multiple root causes are plausible
- Architecture or design decisions with hidden tradeoffs
- Any situation where first-plausible-answer syndrome is a risk
- Safety-critical or high-stakes reasoning

## When NOT to Use

- Trivial fact recall
- Simple arithmetic (unless ambiguity exists)
- Purely stylistic writing tasks
- Low-stakes conversational questions

For those, answer directly with a quick assumption spot-check.

## Procedure

### Stage 1: Problem Framing

State precisely:
- What question is actually being asked
- What the key unknowns are
- What constraints must be preserved
- What ambiguities could materially change the answer

If ambiguity exists, either branch explicitly or state the dominant interpretation and why.

### Stage 2: Candidate Space

List 2–4 plausible candidates, interpretations, or solution paths.
Only include candidates that are actually plausible — not combinatorial noise.

### Stage 3: Assumption Extraction

For each candidate, identify:
- Explicit assumptions
- Hidden assumptions
- Definitional dependencies
- Required environmental conditions

### Stage 4: Negative Analysis (Internal)

For each weak or invalid candidate, provide:
- **Failure label(s)** from the typed list below
- Concise explanation of why it fails
- Whether the failure is fatal or repairable
- A counterexample or contradiction when available

**Allowed failure labels:**
`false_premise` · `unsupported_assumption` · `invalid_inference` · `missing_constraint` ·
`boundary_condition_failure` · `contradiction_with_known_facts` · `internal_inconsistency` ·
`category_error` · `equivocation` · `overgeneralization` · `underspecified_claim` ·
`solves_adjacent_problem` · `locally_valid_globally_invalid` · `circular_reasoning` ·
`non_falsifiable` · `conclusion_too_strong`

If none apply cleanly, say so explicitly and describe the uncertainty.

### Stage 5: Positive Construction

Build the strongest surviving candidate:
- Restate allowed assumptions
- Show the valid inference chain
- Identify the exact structural difference from failed candidates
- State the answer with calibrated confidence

The answer must be **contrastive** — it must explain why it is right *relative to* the nearby wrong answers.

### Stage 6: Cross-Model Adversarial Critique

**This is the key step.** Do NOT self-critique here. Shell out to independent models.

Format a payload containing:
1. The original question
2. The positive candidate from Stage 5
3. The assumptions it relies on
4. The rejected alternatives and why they were rejected
5. The inference chain

Then call the adversarial critique script via terminal:

```bash
cat <<'PAYLOAD' | /path/to/adversarial-reasoning/scripts/adversarial-critique.sh
QUESTION:
<the original question>

POSITIVE CANDIDATE:
<the answer from Stage 5>

ASSUMPTIONS:
<numbered list of assumptions this answer relies on>

REJECTED ALTERNATIVES:
<for each rejected candidate: what it claimed and why it was rejected>

INFERENCE CHAIN:
<the step-by-step reasoning that produced the positive candidate>
PAYLOAD
```

Parse the JSON response. Each critic will return:
- `survival`: survives / damaged / fatal
- `issues[]`: typed failure labels with targets, critiques, severities
- `hidden_assumptions_found[]`
- `edge_cases_tested[]`
- `overall_note`: weakest link assessment

The response also includes `consensus` (combined verdict) and `agreement` (unanimous/partial).

**Rules for handling verdicts:**
- If consensus is `fatal` — the candidate has a structural flaw. Return to Stage 5 with the specific issues and reconstruct.
- If consensus is `damaged` — the candidate has problems but may be repairable. Address each serious issue. If repaired, note what changed.
- If consensus is `survives` — proceed to Stage 7. Still note any minor issues.
- If critics disagree — investigate the specific points of disagreement. The truth is usually in the details.
- If all critics unavailable — self-critique with extra skepticism and mark the answer as `unverified_by_independent_critique`.

**Do NOT dismiss critics' findings without explanation.** If you disagree with a specific issue, state why with the same rigor you'd apply to any other claim.

### Stage 7: Final Answer

Deliver:
- The best surviving answer (post-critique)
- The most important rejected alternative and why it failed
- The main assumption on which the conclusion depends
- Confidence level: `high` / `medium` / `low`
- What would change the answer (what new information would flip it)
- Critic consensus and whether any issues were addressed

## Behavioral Rules

1. **Never accept first-plausible-answer syndrome.** At least one competing candidate must be considered.
2. **Criticism must be typed.** No "this seems wrong" without a failure label.
3. **The final answer must be contrastive.** Why right relative to nearby wrong.
4. **Rhetoric is not evidence.** Elegant prose does not substitute for valid inference.
5. **Candidate sets must be disciplined.** Plausible, not exhaustive.
6. **Ambiguity surfaces early.** Before analysis, not after.
7. **Conclusion matches support.** Never claim certainty when only plausibility is established.
8. **Independent critique is real input, not theater.** Engage with it substantively.
9. **Distinguish fatal vs repairable failures.** Some candidates are wrong at the root; others need one condition added.
10. **Never merge incompatible frameworks silently.** If two candidates use different definitions, keep that explicit.

## Lightweight Mode

For problems that warrant adversarial care but not the full 7-stage treatment:

1. State the answer
2. State the strongest counter-argument
3. Shell out with a compact payload (question + answer + one alternative)
4. Incorporate critique
5. Deliver with confidence level

## Failure Modes of This Skill

Watch for:
- Performative critique with no logical bite (from any model)
- Too many low-value candidates flooding the process
- Mislabeled failures
- Mistaking skepticism for rigor
- Over-pruning genuinely valid but unusual answers
- False precision in confidence statements
- Treating any single critic's verdict as infallible (every model has blind spots — just different ones)
