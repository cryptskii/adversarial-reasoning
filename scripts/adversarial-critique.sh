#!/usr/bin/env bash
# Adversarial Critique — Multi-Backend
#
# Pipes a reasoning payload to one or more independent AI models
# and collects structured adversarial critique from each.
#
# Usage:
#   echo "$REASONING_PAYLOAD" | ./adversarial-critique.sh
#
# Supports: Gemini CLI, Ollama (any model), OpenAI Codex CLI
# Configure backends in config.json (same directory as this script)
#
# Output: JSON with verdicts from each available critic

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$SCRIPT_DIR/config.json"

# ─── Read config (lightweight JSON parsing via python) ───
if [ ! -f "$CONFIG" ]; then
    echo '{"error":"No config.json found. Copy config.example.json to config.json and configure your backends."}' >&2
    exit 1
fi

# Read payload from stdin into temp file
TMPFILE=$(mktemp /tmp/adversarial-critique.XXXXXX)
trap 'rm -f "$TMPFILE" /tmp/adversarial-gemini.$$ /tmp/adversarial-ollama.$$ /tmp/adversarial-codex.$$' EXIT
cat > "$TMPFILE"

if [ ! -s "$TMPFILE" ]; then
    echo '{"error":"No reasoning payload provided via stdin"}'
    exit 1
fi

PAYLOAD=$(cat "$TMPFILE")

# ─── System prompt (shared across all backends) ───
SYSTEM_PROMPT='You are an adversarial logic reviewer. Your ONLY job is to attack the reasoning you are given and find flaws. You are not helpful, not collaborative, not constructive. You are a hostile examiner trying to break the argument.

For every claim, ask: Does this follow from the stated assumptions? Are there hidden assumptions? Does this break at edge cases? Is the conclusion stronger than evidence supports? Is it solving the actual question asked?

Classify every issue using EXACTLY one of these labels:
false_premise, unsupported_assumption, invalid_inference, missing_constraint, boundary_condition_failure, contradiction_with_known_facts, internal_inconsistency, category_error, equivocation, overgeneralization, underspecified_claim, solves_adjacent_problem, locally_valid_globally_invalid, circular_reasoning, non_falsifiable, conclusion_too_strong

Reply ONLY with valid JSON, no markdown fences, no explanation outside the JSON:
{"survival":"survives|damaged|fatal","issues":[{"label":"<type>","target":"<claim>","critique":"<explanation>","severity":"fatal|serious|minor","counterexample":"<or null>"}],"hidden_assumptions_found":["..."],"edge_cases_tested":["..."],"overall_note":"weakest link"}'

USER_PROMPT="Here is a structured reasoning attempt. Attack it. Find every flaw. Classify each one. If it genuinely survives your attack, say so — but your bias is toward finding problems, not confirming answers.

${PAYLOAD}"

# ─── Strip markdown fences from model output ───
strip_fences() {
    sed 's/^```json//;s/^```//;s/```$//' | sed '/^[[:space:]]*$/d'
}

# ─── Gemini Flash ───
call_gemini() {
    local binary model timeout
    binary=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['gemini']['binary'])" 2>/dev/null || echo "")
    model=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['gemini']['model'])" 2>/dev/null || echo "gemini-2.5-flash")
    timeout_s=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['gemini'].get('timeout', 45))" 2>/dev/null || echo "45")
    enabled=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['gemini']['enabled'])" 2>/dev/null || echo "False")

    if [ "$enabled" != "True" ] || [ -z "$binary" ] || [ ! -x "$binary" ]; then
        echo '{"status":"disabled"}'
        return
    fi

    local raw
    raw=$(printf '%s' "$USER_PROMPT" | timeout "$timeout_s" "$binary" --no-sandbox -p "$SYSTEM_PROMPT" --model "$model" 2>/dev/null || true)

    if [ -z "$raw" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Gemini was unavailable."}'
        return
    fi

    printf '%s' "$raw" | strip_fences
}

# ─── Ollama (DeepSeek, Llama, Mistral, etc.) ───
call_ollama() {
    local binary model timeout_s
    binary=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['ollama']['binary'])" 2>/dev/null || echo "")
    model=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['ollama']['model'])" 2>/dev/null || echo "deepseek-r1:8b")
    timeout_s=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['ollama'].get('timeout', 60))" 2>/dev/null || echo "60")
    enabled=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['ollama']['enabled'])" 2>/dev/null || echo "False")

    if [ "$enabled" != "True" ] || [ -z "$binary" ]; then
        echo '{"status":"disabled"}'
        return
    fi

    # Check if ollama is running
    if ! curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Ollama server not running. Start with: ollama serve"}'
        return
    fi

    # Ollama API call (more reliable than CLI for structured output)
    local raw
    raw=$(curl -sf --max-time "$timeout_s" http://127.0.0.1:11434/api/generate \
        -d "$(python3 -c "
import json, sys
print(json.dumps({
    'model': '$model',
    'prompt': '''$SYSTEM_PROMPT\n\n$USER_PROMPT''',
    'stream': False,
    'options': {'temperature': 0.3}
}))
" 2>/dev/null)" 2>/dev/null || true)

    if [ -z "$raw" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Ollama call failed."}'
        return
    fi

    # Extract response text from Ollama JSON
    local response_text
    response_text=$(printf '%s' "$raw" | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || true)

    if [ -z "$response_text" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Ollama returned empty response."}'
        return
    fi

    printf '%s' "$response_text" | strip_fences
}

# ─── Codex CLI (OpenAI) ───
call_codex() {
    local binary timeout_s
    binary=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['codex']['binary'])" 2>/dev/null || echo "")
    timeout_s=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['codex'].get('timeout', 60))" 2>/dev/null || echo "60")
    enabled=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c['critics']['codex']['enabled'])" 2>/dev/null || echo "False")

    if [ "$enabled" != "True" ] || [ -z "$binary" ] || ! command -v "$binary" > /dev/null 2>&1; then
        echo '{"status":"disabled"}'
        return
    fi

    local raw
    raw=$(printf '%s' "$USER_PROMPT" | timeout "$timeout_s" "$binary" exec --ephemeral -q "$SYSTEM_PROMPT" - 2>/dev/null || true)

    if [ -z "$raw" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Codex CLI was unavailable."}'
        return
    fi

    printf '%s' "$raw" | strip_fences
}

# ─── Run all enabled critics ───
GEMINI_RESULT=$(call_gemini)
OLLAMA_RESULT=$(call_ollama)
CODEX_RESULT=$(call_codex)

# ─── Determine consensus ───
python3 -c "
import json, sys

results = {}
for name, raw in [('gemini', '''$GEMINI_RESULT'''), ('ollama', '''$OLLAMA_RESULT'''), ('codex', '''$CODEX_RESULT''')]:
    try:
        parsed = json.loads(raw)
        if parsed.get('status') in ('disabled', None) and 'survival' not in parsed:
            continue
        results[name] = parsed
    except:
        continue

if not results:
    print(json.dumps({'error': 'No critics were available', 'critics': {}}))
    sys.exit(0)

# Determine consensus
survivals = [r.get('survival', 'unknown') for r in results.values() if r.get('status') != 'unavailable']
survivals = [s for s in survivals if s != 'unknown']

if not survivals:
    consensus = 'unknown'
    agreement = 'none'
elif all(s == survivals[0] for s in survivals):
    consensus = survivals[0]
    agreement = 'unanimous'
elif 'fatal' in survivals:
    consensus = 'fatal'
    agreement = 'partial'
elif 'damaged' in survivals:
    consensus = 'damaged'
    agreement = 'partial'
else:
    consensus = survivals[0]
    agreement = 'partial'

output = {
    'critics': results,
    'consensus': consensus,
    'agreement': agreement,
    'critics_reporting': len(survivals)
}
print(json.dumps(output, indent=2))
" 2>/dev/null || echo '{"error":"Failed to parse critic results"}'
