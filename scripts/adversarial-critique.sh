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

if [ ! -f "$CONFIG" ]; then
    echo '{"error":"No config.json found. Copy config.example.json to config.json and configure your backends."}' >&2
    exit 1
fi

# ─── Temp files for safe data passing ───
TMPDIR_WORK=$(mktemp -d /tmp/adversarial.XXXXXX)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

PAYLOAD_FILE="$TMPDIR_WORK/payload.txt"
SYSTEM_FILE="$TMPDIR_WORK/system.txt"
USER_FILE="$TMPDIR_WORK/user.txt"
GEMINI_FILE="$TMPDIR_WORK/gemini.json"
OLLAMA_FILE="$TMPDIR_WORK/ollama.json"
CODEX_FILE="$TMPDIR_WORK/codex.json"

# Read payload from stdin
cat > "$PAYLOAD_FILE"

if [ ! -s "$PAYLOAD_FILE" ]; then
    echo '{"error":"No reasoning payload provided via stdin"}'
    exit 1
fi

# ─── System prompt (shared across all backends) ───
cat > "$SYSTEM_FILE" <<'SYSPROMPT'
You are an adversarial logic reviewer. Your ONLY job is to attack the reasoning you are given and find flaws. You are not helpful, not collaborative, not constructive. You are a hostile examiner trying to break the argument.

For every claim, ask: Does this follow from the stated assumptions? Are there hidden assumptions? Does this break at edge cases? Is the conclusion stronger than evidence supports? Is it solving the actual question asked?

Classify every issue using EXACTLY one of these labels:
false_premise, unsupported_assumption, invalid_inference, missing_constraint, boundary_condition_failure, contradiction_with_known_facts, internal_inconsistency, category_error, equivocation, overgeneralization, underspecified_claim, solves_adjacent_problem, locally_valid_globally_invalid, circular_reasoning, non_falsifiable, conclusion_too_strong

Reply ONLY with valid JSON, no markdown fences, no explanation outside the JSON:
{"survival":"survives|damaged|fatal","issues":[{"label":"<type>","target":"<claim>","critique":"<explanation>","severity":"fatal|serious|minor","counterexample":"<or null>"}],"hidden_assumptions_found":["..."],"edge_cases_tested":["..."],"overall_note":"weakest link"}
SYSPROMPT

# Build user prompt
{
    echo "Here is a structured reasoning attempt. Attack it. Find every flaw. Classify each one. If it genuinely survives your attack, say so — but your bias is toward finding problems, not confirming answers."
    echo ""
    cat "$PAYLOAD_FILE"
} > "$USER_FILE"

# ─── Config reader ───
read_config() {
    python3 -c "import json; c=json.load(open('$CONFIG')); print(c$1)" 2>/dev/null || echo "$2"
}

# ─── Strip markdown fences from model output ───
strip_fences() {
    sed 's/^```json//;s/^```//;s/```$//' | sed '/^[[:space:]]*$/d'
}

# ─── Gemini Flash ───
call_gemini() {
    local binary model timeout_s enabled
    enabled=$(read_config "['critics']['gemini']['enabled']" "False")
    binary=$(read_config "['critics']['gemini']['binary']" "")
    model=$(read_config "['critics']['gemini']['model']" "gemini-2.5-flash")
    timeout_s=$(read_config "['critics']['gemini'].get('timeout', 45)" "45")

    if [ "$enabled" != "True" ] || [ -z "$binary" ] || [ ! -x "$binary" ]; then
        echo '{"status":"disabled"}'
        return
    fi

    local raw
    raw=$(cat "$USER_FILE" | timeout "$timeout_s" "$binary" --no-sandbox -p "$(cat "$SYSTEM_FILE")" --model "$model" 2>/dev/null || true)

    if [ -z "$raw" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Gemini was unavailable."}'
        return
    fi

    printf '%s' "$raw" | strip_fences
}

# ─── Ollama (DeepSeek, Llama, Mistral, etc.) ───
call_ollama() {
    local binary model timeout_s enabled
    enabled=$(read_config "['critics']['ollama']['enabled']" "False")
    binary=$(read_config "['critics']['ollama']['binary']" "")
    model=$(read_config "['critics']['ollama']['model']" "deepseek-r1:8b")
    timeout_s=$(read_config "['critics']['ollama'].get('timeout', 60)" "60")

    if [ "$enabled" != "True" ] || [ -z "$binary" ]; then
        echo '{"status":"disabled"}'
        return
    fi

    # Check if ollama is running
    if ! curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Ollama server not running. Start with: ollama serve"}'
        return
    fi

    # Build request JSON safely via python reading from files
    local request_json
    request_json=$(python3 -c "
import json
system = open('$SYSTEM_FILE').read()
user = open('$USER_FILE').read()
print(json.dumps({
    'model': '$model',
    'prompt': system + '\n\n' + user,
    'stream': False,
    'options': {'temperature': 0.3}
}))
" 2>/dev/null)

    if [ -z "$request_json" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Failed to build Ollama request."}'
        return
    fi

    local raw
    printf '%s' "$request_json" > "$TMPDIR_WORK/ollama_request.json"
    raw=$(curl -sf --max-time "$timeout_s" -d @"$TMPDIR_WORK/ollama_request.json" http://127.0.0.1:11434/api/generate 2>/dev/null || true)

    if [ -z "$raw" ]; then
        echo '{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Ollama call failed or timed out."}'
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
    local binary timeout_s enabled
    enabled=$(read_config "['critics']['codex']['enabled']" "False")
    binary=$(read_config "['critics']['codex']['binary']" "")
    timeout_s=$(read_config "['critics']['codex'].get('timeout', 60)" "60")

    if [ "$enabled" != "True" ] || [ -z "$binary" ] || ! command -v "$binary" > /dev/null 2>&1; then
        echo '{"status":"disabled"}'
        return
    fi

    local raw
    raw=$(cat "$USER_FILE" | timeout "$timeout_s" "$binary" exec --ephemeral -q "$(cat "$SYSTEM_FILE")" - 2>/dev/null || true)

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

# ─── Write results to files for safe python parsing ───
printf '%s' "$GEMINI_RESULT" > "$GEMINI_FILE"
printf '%s' "$OLLAMA_RESULT" > "$OLLAMA_FILE"
printf '%s' "$CODEX_RESULT" > "$CODEX_FILE"

# ─── Determine consensus ───
export TMPDIR_WORK
python3 << 'CONSENSUS'
import json, sys, os

tmpdir = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('TMPDIR_WORK', '/tmp')

results = {}
for name in ['gemini', 'ollama', 'codex']:
    fpath = os.path.join(tmpdir, f'{name}.json')
    try:
        with open(fpath) as f:
            raw = f.read().strip()
        if not raw:
            continue
        parsed = json.loads(raw)
        if parsed.get('status') == 'disabled':
            continue
        results[name] = parsed
    except:
        continue

if not results:
    print(json.dumps({'error': 'No critics were available', 'critics': {}}))
    sys.exit(0)

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
CONSENSUS
