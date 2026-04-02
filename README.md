# Adversarial Reasoning

**Multi model adversarial critique for AI reasoning.**

A structured system that uses independent AI models to attack reasoning catching errors that single model self correction systematically misses.

## The Problem

When an AI model checks its own work, it shares its own blind spots. Asking GPT to review GPT's reasoning, or Claude to critique Claude's logic, is like asking the person who wrote the bug to also find it. The critic has the same training biases, the same knowledge gaps, and the same failure modes as the builder.

The industry's current answer is "retry harder" run the same model again, maybe with chain-of-thought, maybe with a different temperature. This is self correction, not verification. It's structurally incapable of catching errors the model is blind to.

## The Solution

Use **a different vendor's model** as an independent adversarial critic, with structured payloads and typed failure classification.

```
┌─────────────────────────────────┐
│  Claude (or any model)          │
│  Builds the reasoning           │
│  Stages 1-5: Candidates →       │
│  Assumptions → Negative          │
│  Analysis → Positive             │
│  Construction                    │
└──────────────┬──────────────────┘
               │ structured payload
               ▼
┌──────────────────────────────────┐
│  Gemini Flash (Google)           │
│                                  │
│  Independent adversarial critic  │
│  Different training data         │
│  Different blind spots           │
│  Typed failure classification    │
└──────────────┬──────────────────┘
               │
               ▼
    ┌─────────────────────────────┐
    │  Structured verdict         │
    │  survives / damaged / fatal │
    │  Typed failure labels       │
    │  Hidden assumptions found   │
    │  Edge cases tested          │
    └──────────────┬──────────────┘
                   │
                   ▼
    ┌─────────────────────────────┐
    │  Final answer               │
    │  Incorporating independent  │
    │  critique                   │
    └─────────────────────────────┘
```

This is **not** model routing (picking the best model per request). This is **not** ensemble averaging. This is adversarial triangulation an independent critic attacking reasoning from a different angle, with structured failure classification that makes the critique actionable.

## How It Differs From Existing Tools

| Feature | Copilot / Cursor / Codex | This System |
|---------|--------------------------|-------------|
| Models used | One per request | Builder + independent critic |
| Self-correction | Same model retries | Different model attacks |
| Failure classification | "Try again" | Typed labels (16 categories) |
| Intervention protocol | Binary pass/fail | survives / damaged / fatal |
| Blind spot coverage | Same as builder | Structurally independent |

## Quick Start

### Prerequisites

**Gemini CLI** (free most generous free tier of any model CLI):
```bash
npm install -g @google/gemini-cli

# Login (just needs a Google account)
gemini auth login
```

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/adversarial-reasoning.git
cd adversarial-reasoning

# Make scripts executable
chmod +x scripts/*.sh

# Copy config and set your Gemini path
cp config.example.json config.json
```

### Configuration

Edit `config.json` to point to your Gemini binary:

```json
{
  "critics": {
    "gemini": {
      "enabled": true,
      "binary": "/opt/homebrew/bin/gemini",
      "model": "gemini-2.5-flash",
      "timeout": 45
    }
  }
}
```

To find your Gemini binary path: `which gemini`

### Usage

Pipe a structured reasoning payload to the critique script:

```bash
cat <<'PAYLOAD' | ./scripts/adversarial-critique.sh
QUESTION:
If you flip a fair coin 100 times and get heads every time,
is the next flip more likely to be tails?

POSITIVE CANDIDATE:
No. Each flip is independent. P(heads) = 0.5 regardless of
prior results. The gambler's fallacy incorrectly assumes dependence.

ASSUMPTIONS:
1. The coin is fair (exactly 50/50)
2. Each flip is independent
3. The question asks about the NEXT flip, not the sequence

REJECTED ALTERNATIVES:
A: Yes, tails is "due" — gambler's fallacy, rejected because
independence means prior outcomes are irrelevant

INFERENCE CHAIN:
1. Fair coin means P(H) = P(T) = 0.5
2. Independence means P(flip 101 | first 100) = P(flip 101)
3. Prior outcomes do not change the probability
4. Therefore P(heads on 101) = 0.5
PAYLOAD
```

The script returns structured JSON:

```json
{
  "critics": {
    "gemini": {
      "survival": "fatal",
      "issues": [
        {
          "label": "unsupported_assumption",
          "target": "The coin is fair (exactly 50/50)",
          "critique": "100 consecutive heads is so improbable for a fair coin (1 in 2^100) that a rational Bayesian observer should question the fairness assumption itself, not take it as axiomatic.",
          "severity": "fatal",
          "counterexample": null
        }
      ],
      "hidden_assumptions_found": [
        "The problem requires treating 'fair coin' as immune to empirical challenge from observed data."
      ],
      "overall_note": "The reasoning is sound only if the fairness premise is unchallengeable. The extreme observation destabilizes that premise."
    }
  },
  "consensus": "fatal",
  "agreement": "unanimous",
  "critics_reporting": 1
}
```

### Intervention Protocol

| Verdict | Meaning | Action |
|---------|---------|--------|
| `survives` | No issues found or only minor | Proceed with the answer |
| `damaged` | Serious issues but repairable | Address each issue, repair |
| `fatal` | Fundamental structural flaw | Rebuild from scratch |

## Payload Format

The structured payload is what makes this work. Critics need the reasoning in a form they can attack.

```
QUESTION:
[The original question being answered]

POSITIVE CANDIDATE:
[The proposed answer — the thing being tested]

ASSUMPTIONS:
[Numbered list of assumptions this answer relies on]

REJECTED ALTERNATIVES:
[What other answers were considered and why they were rejected]

INFERENCE CHAIN:
[Step-by-step reasoning that produced the positive candidate]
```

## Failure Labels

Every issue must be classified. No "this seems wrong" without a type.

| Label | Meaning |
|-------|---------|
| `false_premise` | Starting assumption is factually wrong |
| `unsupported_assumption` | Assumption lacks justification |
| `invalid_inference` | Conclusion doesn't follow from premises |
| `missing_constraint` | Important condition not accounted for |
| `boundary_condition_failure` | Breaks at edge cases |
| `contradiction_with_known_facts` | Conflicts with established knowledge |
| `internal_inconsistency` | Contradicts itself |
| `category_error` | Mixes incompatible types or levels |
| `equivocation` | Definition shifts between steps |
| `overgeneralization` | Conclusion broader than evidence supports |
| `underspecified_claim` | Too vague to evaluate |
| `solves_adjacent_problem` | Answers a different question |
| `locally_valid_globally_invalid` | Each step ok, whole argument broken |
| `circular_reasoning` | Conclusion assumed in premises |
| `non_falsifiable` | Cannot be tested or disproven |
| `conclusion_too_strong` | Evidence supports weaker claim |

## Real Test Results

### Test 1: Surprise Examination Paradox

**Setup:** Claude built a 5-stage analysis arguing the backward induction is "self-defeating" because the conclusion restores conditions for surprise.

**Gemini verdict: `damaged`**
- `internal_inconsistency`: The argument describes the paradox's circular structure rather than resolving it.
- `category_error`: Using the empirical Wednesday exam to refute a logical argument mixes categories.

**Result:** Answer revised to specify the *mechanism* of failure (premise consumption during induction) rather than just naming the circular structure.

### Test 2: Gödel's Theorem and Second-Order Arithmetic

**Setup:** Claude argued Gödel's theorem "doesn't apply" to second-order PA because it's "not effectively axiomatizable."

**Gemini verdict: `fatal`**
- `false_premise`: Second-order PA's axiom system is finite and thus effectively axiomatizable. The argument confuses the axiom system with Th(ℕ).
- `category_error`: Conflating the formal system with its semantic consequences.

**Result:** Gemini was right. The answer was fundamentally wrong — Gödel's theorem *does* apply. Claude had confused two distinct mathematical objects. No self-correction would have caught this.

### Test 3: Gambler's Fallacy (Coin Flip)

**Setup:** Claude gave the textbook answer — 100 heads doesn't affect flip 101, each flip is independent, gambler's fallacy.

**Gemini verdict: `fatal`**
- `unsupported_assumption`: 100 consecutive heads (probability 1 in 2^100) should cause a rational Bayesian to question the fairness assumption itself, not treat it as axiomatic.

**Result:** Gemini found a hidden assumption in what most people consider a textbook correct answer. The "fair coin" premise was treated as definitional rather than as a hypothesis challengeable by evidence.

## Integration with Claude Code

Drop the skill file into your skills directory:

```bash
mkdir -p /path/to/your/project/.claude/skills/adversarial-reasoning
cp skill/SKILL.md /path/to/your/project/.claude/skills/adversarial-reasoning/SKILL.md
cp scripts/adversarial-critique.sh /path/to/your/project/.claude/hooks/adversarial-critique.sh
chmod +x /path/to/your/project/.claude/hooks/adversarial-critique.sh
```

The skill instructs Claude to call the script at Stage 6 (Resubmission to Critique) automatically.

## Adding More Backends

The script supports multiple critic backends. To add another model CLI, add a section to `config.json` and a call function in the script. Any model with CLI access works. The architecture is designed so critics are interchangeable — swap them, add them, remove them without changing the core workflow.

## Why This Works

Different models trained by different labs on different data with different RLHF pipelines have different failure modes. When Claude confuses an axiom system with the theory of its standard model, Gemini — trained differently — doesn't share that confusion.

This isn't about any individual model being "better." It's about the *combination* catching errors that any single model structurally cannot. The same principle behind code review, peer review, and adversarial legal proceedings: independent evaluation by parties with different perspectives.

## Limitations

- **Shared blind spots exist.** If both models share a misconception, cross-model critique won't catch it.
- **Structured payloads require effort.** You have to formulate your reasoning clearly enough for the critic to attack. This is also a feature — structuring the payload often reveals problems on its own.
- **Not useful for trivial tasks.** Don't adversarial-critique "write me a for loop."
- **Dependent on critic availability.** Cloud-based critics can hit capacity limits. The script handles this gracefully (returns unavailable, consensus adjusts).

## License

MIT

## Contributing

The most valuable contributions are:
1. **New test cases** — especially ones where the system fails or produces surprising results
2. **New backend integrations** — more model diversity = more blind spot coverage
3. **Failure mode documentation** — when does cross-model critique NOT help?
4. **Payload format improvements** — better structured inputs = better critique
