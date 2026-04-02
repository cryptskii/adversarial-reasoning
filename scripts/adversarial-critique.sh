#!/usr/bin/env bash
# Adversarial Critique via Gemini Flash
#
# Pipes a reasoning payload to Gemini 2.5 Flash and gets back
# structured adversarial critique with typed failure labels.
#
# Usage:
#   cat payload.txt | ./adversarial-critique.sh
#
# Configure Gemini binary and model in config.json (parent directory)
#
# Output: JSON with verdict from Gemini

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$SCRIPT_DIR/config.json"

if [ ! -f "$CONFIG" ]; then
    echo '{"error":"No config.json found. Copy config.example.json to config.json and set your Gemini path."}' >&2
    exit 1
fi

# ─── Temp files ───
TMPDIR_WORK=$(mktemp -d /tmp/adversarial.XXXXXX)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# Read payload from stdin
cat > "$TMPDIR_WORK/payload.txt"

if [ ! -s "$TMPDIR_WORK/payload.txt" ]; then
    echo '{"error":"No reasoning payload provided via stdin"}'
    exit 1
fi

# ─── System prompt ───
cat > "$TMPDIR_WORK/system.txt" <<'SYSPROMPT'
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
    cat "$TMPDIR_WORK/payload.txt"
} > "$TMPDIR_WORK/user.txt"

# ─── Read config ───
read_config() {
    python3 -c "import json; c=json.load(open('$CONFIG')); print(c$1)" 2>/dev/null || echo "$2"
}

# ─── Strip markdown fences ───
strip_fences() {
    sed 's/^```json//;s/^```//;s/```$//' | sed '/^[[:space:]]*$/d'
}

# ─── Call Gemini ───
BINARY=$(read_config "['critics']['gemini']['binary']" "")
MODEL=$(read_config "['critics']['gemini']['model']" "gemini-2.5-flash")
TIMEOUT=$(read_config "['critics']['gemini'].get('timeout', 45)" "45")
ENABLED=$(read_config "['critics']['gemini']['enabled']" "False")

if [ "$ENABLED" != "True" ] || [ -z "$BINARY" ] || [ ! -x "$BINARY" ]; then
    echo '{"error":"Gemini not configured. Check config.json."}'
    exit 1
fi

RAW=$(cat "$TMPDIR_WORK/user.txt" | timeout "$TIMEOUT" "$BINARY" --no-sandbox -p "$(cat "$TMPDIR_WORK/system.txt")" --model "$MODEL" 2>/dev/null || true)

if [ -z "$RAW" ]; then
    echo '{"critics":{"gemini":{"status":"unavailable","survival":"unknown","issues":[],"hidden_assumptions_found":[],"edge_cases_tested":[],"overall_note":"Gemini was unavailable."}},"consensus":"unknown","critics_reporting":0}'
    exit 0
fi

# Write verdict to file, strip fences, wrap in output format
printf '%s' "$RAW" | strip_fences > "$TMPDIR_WORK/verdict.json"

export TMPDIR_WORK
python3 << 'WRAP'
import json, os

tmpdir = os.environ['TMPDIR_WORK']
try:
    with open(os.path.join(tmpdir, 'verdict.json')) as f:
        v = json.loads(f.read().strip())
except:
    v = {"status": "parse_error", "survival": "unknown", "issues": [], "overall_note": "Failed to parse Gemini response."}

output = {
    "critics": {"gemini": v},
    "consensus": v.get("survival", "unknown"),
    "critics_reporting": 1 if v.get("survival", "unknown") != "unknown" else 0
}
print(json.dumps(output, indent=2))
WRAP
