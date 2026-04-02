# Adversarial Reasoning

**Multi-model adversarial critique for AI reasoning.**

A structured system that uses multiple AI models from different vendors to attack each other's reasoning — catching errors that single-model self-correction systematically misses.

## The Problem

When an AI model checks its own work, it shares its own blind spots. Asking GPT to review GPT's reasoning, or Claude to critique Claude's logic, is like asking the person who wrote the bug to also find it. The critic has the same training biases, the same knowledge gaps, and the same failure modes as the builder.

The industry's current answer is "retry harder" — run the same model again, maybe with chain-of-thought, maybe with a different temperature. This is self-correction, not verification. It's structurally incapable of catching errors the model is blind to.

## The Solution

Use **multiple models from different vendors** as independent adversarial critics, with structured payloads and typed failure classification.

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
│  Gemini Flash    │  DeepSeek R1  │
│  (Google)        │  (local/Ollama)│
│                  │               │
│  Independent adversarial critics │
│  Different training data         │
│  Different blind spots           │
│  Typed failure classification    │
└──────────┬───────┴───────┬──────┘
           │               │
           ▼               ▼
    ┌─────────────────────────────┐
    │  Structured verdicts        │
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
    │  critique from all models   │
    └─────────────────────────────┘
```

This is **not** model routing (picking the best model per request). This is **not** ensemble averaging. This is adversarial triangulation — multiple independent critics attacking the same reasoning from different angles, with structured failure classification that makes the critique actionable.

## How It Differs From Existing Tools

| Feature | Copilot / Cursor / Codex | This System |
|---------|--------------------------|-------------|
| Models used | One per request | Multiple simultaneously |
| Self-correction | Same model retries | Different models attack |
| Failure classification | "Try again" | Typed labels (16 categories) |
| Intervention protocol | Binary pass/fail | survives / damaged / fatal |
| Blind spot coverage | Same as builder | Structurally independent |
| Vendor lock-in | Single vendor | Multi-vendor by design |

## Quick Start

### Prerequisites

You need at least one CLI model tool. More = more diverse critique.

**Gemini CLI** (recommended first — most generous free tier):
```bash
# Install
npm install -g @anthropic-ai/gemini-cli
# or
brew install gemini

# Login (just needs a Google account — free)
gemini auth login
```

**Ollama + DeepSeek R1** (recommended second — local, unlimited, different training):
```bash
# Install Ollama
brew install ollama

# Start the server
ollama serve &

# Pull DeepSeek R1 (reasoning-focused, ~5GB)
ollama pull deepseek-r1:8b
```

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/adversarial-reasoning.git
cd adversarial-reasoning

# Make scripts executable
chmod +x scripts/*.sh

# Copy config and set your preferences
cp config.example.json config.json
```

### Configuration

Edit `config.json` to specify which backends you have available:

```json
{
  "critics": {
    "gemini": {
      "enabled": true,
      "binary": "/opt/homebrew/bin/gemini",
      "model": "gemini-2.5-flash",
      "timeout": 45
    },
    "ollama": {
      "enabled": true,
      "binary": "/usr/local/bin/ollama",
      "model": "deepseek-r1:8b",
      "timeout": 60
    }
  },
  "require_all_critics": false,
  "min_critics": 1
}
```

### Usage

Pipe a structured reasoning payload to the critique script:

```bash
cat <<'PAYLOAD' | ./scripts/adversarial-critique.sh
QUESTION:
Does Gödel's First Incompleteness Theorem apply to second-order PA?

POSITIVE CANDIDATE:
No, because second-order PA is not effectively axiomatizable...

ASSUMPTIONS:
1. Gödel's theorem requires effective axiomatizability
2. Second-order PA with standard semantics is categorical
...

REJECTED ALTERNATIVES:
A: Yes Gödel applies — rejected because...

INFERENCE CHAIN:
1. Theorem preconditions: consistent, effectively axiomatizable...
2. Second-order PA: not effectively axiomatizable...
...
PAYLOAD
```

The script returns structured JSON from each available critic:

```json
{
  "critics": {
    "gemini": {
      "survival": "fatal",
      "issues": [
        {
          "label": "false_premise",
          "target": "second-order PA is not effectively axiomatizable",
          "critique": "The axiom system is finite and thus effectively axiomatizable. The argument confuses the axiom system with Th(N).",
          "severity": "fatal",
          "counterexample": null
        }
      ],
      "hidden_assumptions_found": ["Conflates axiom system with complete theory of standard model"],
      "overall_note": "Core premise is wrong — the theorem does apply."
    },
    "deepseek": {
      "survival": "damaged",
      "issues": [...],
      "overall_note": "..."
    }
  },
  "consensus": "fatal",
  "agreement": "partial"
}
```

### Intervention Protocol

| Verdict | Meaning | Action |
|---------|---------|--------|
| `survives` | No issues found or only minor issues | Proceed with the answer |
| `damaged` | Serious issues but potentially repairable | Address each issue, repair, re-critique |
| `fatal` | Fundamental structural flaw | Return to construction, rebuild |

When multiple critics are used:
- **Both fatal** → High confidence the reasoning is broken
- **Both survives** → High confidence the reasoning holds
- **Disagreement** → Investigate the specific issues; the truth is usually in the details

## Payload Format

The structured payload is what makes this work. Critics need the reasoning in a form they can actually attack.

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
- `internal_inconsistency`: The argument describes the paradox's circular structure rather than resolving it. Saying "the conclusion feeds back" names the loop without escaping it.
- `category_error`: Using the empirical Wednesday exam to refute a logical argument mixes categories.

**Result:** Both critiques were substantive. The answer was revised to specify the *mechanism* of failure (premise consumption during induction) rather than just naming the circular structure. Narrower but more defensible.

### Test 2: Gödel's Theorem and Second-Order Arithmetic

**Setup:** Claude built an analysis arguing Gödel's theorem "doesn't apply" to second-order PA because it's "not effectively axiomatizable."

**Gemini verdict: `fatal`**
- `false_premise`: Second-order PA's axiom system is finite and thus effectively axiomatizable. The argument confuses the axiom system with the complete theory of the standard model Th(ℕ).
- `category_error`: Conflating effective axiomatizability of the formal system with recursive enumerability of its semantic consequences.

**Result:** Gemini was right. The answer was fundamentally wrong — Gödel's theorem *does* apply to second-order PA as a formal system. Claude's original analysis had confused two distinct mathematical objects. No amount of self-correction would have caught this because the confusion was in Claude's understanding, not in the surface reasoning.

## Integration with Claude Code / Claude CLI

If you use Claude Code with a skills system, drop the skill file into your skills directory:

```bash
cp skill/SKILL.md /path/to/your/project/.claude/skills/adversarial-reasoning/SKILL.md
cp scripts/adversarial-critique.sh /path/to/your/project/.claude/hooks/adversarial-critique.sh
chmod +x /path/to/your/project/.claude/hooks/adversarial-critique.sh
```

The skill instructs Claude to call the script at Stage 6 (Resubmission to Critique) automatically.

## Adding Your Own Backends

The script is designed to be extended. Each backend is a function that takes a prompt and system message and returns JSON. To add a new one:

1. Add a section to `config.json`
2. Add a call function in `adversarial-critique.sh`
3. The function must return the standard verdict JSON schema

Any model with CLI access works: OpenAI Codex, Mistral, Llama via Ollama, Anthropic API via curl, etc.

## Why This Works

The structural advantage is **blind spot diversity**. Different models trained by different labs on different data with different RLHF pipelines have different failure modes. When Claude confuses an axiom system with the theory of its standard model, Gemini — trained differently — may not share that confusion. When Gemini misses a self-reference issue, DeepSeek — trained on different data with reasoning-specific objectives — might catch it.

This isn't about any individual model being "better." It's about the *combination* catching errors that any single model structurally cannot. The same principle behind code review, peer review, and adversarial legal proceedings: independent evaluation by parties with different perspectives.

## Limitations

- **Shared blind spots still exist.** If all three models share a misconception about an obscure topic, cross-model critique won't save you.
- **Local models are weaker.** An 8B parameter DeepSeek won't produce critique as sharp as Gemini Flash. The value is in diversity, not quality.
- **Structured payloads require effort.** You have to formulate your reasoning clearly enough for the critics to attack it. This is also a feature — the act of structuring the payload often reveals problems.
- **Not useful for trivial tasks.** Don't adversarial-critique "write me a for loop." The overhead isn't worth it for problems without hidden assumptions.

## License

MIT

## Contributing

The most valuable contributions are:
1. **New test cases** — especially ones where the system fails or produces surprising results
2. **New backend integrations** — more model diversity = more blind spot coverage
3. **Failure mode documentation** — when does cross-model critique NOT help?
4. **Payload format improvements** — better structured inputs = better structured critique
