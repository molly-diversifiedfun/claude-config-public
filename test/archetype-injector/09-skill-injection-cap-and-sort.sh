#!/usr/bin/env bash
# Test: archetype with >10 tagged skills → cap at 10, alphabetical sort.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"

# Build a fixture manifest with 15 always-on skills (>10)
FIXTURE="/tmp/test-skill-archetypes-09.yaml"
cat > "$FIXTURE" <<'EOF'
"zzz-skill": [always-on]
"yyy-skill": [always-on]
"xxx-skill": [always-on]
"www-skill": [always-on]
"vvv-skill": [always-on]
"uuu-skill": [always-on]
"ttt-skill": [always-on]
"sss-skill": [always-on]
"rrr-skill": [always-on]
"qqq-skill": [always-on]
"ppp-skill": [always-on]
"ooo-skill": [always-on]
"nnn-skill": [always-on]
"mmm-skill": [always-on]
"lll-skill": [always-on]
EOF

# Swap fixture in for original manifest
ORIG_MANIFEST="$HOME/.claude/skill-archetypes.yaml"
BACKUP="/tmp/test-09-original-manifest.yaml.bak"
cp "$ORIG_MANIFEST" "$BACKUP" 2>/dev/null || true
cp "$FIXTURE" "$ORIG_MANIFEST"

# Bust cache + run with archetype that won't match anything specific (always-on still fires)
rm -f "$HOME/.claude/checkpoints/archetype-cache.json"
INPUT='{"cwd":"$HOME/no-such-dir","prompt":"hello"}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)

# Restore original
if [ -f "$BACKUP" ]; then
  cp "$BACKUP" "$ORIG_MANIFEST"
  rm -f "$BACKUP"
else
  rm -f "$ORIG_MANIFEST"
fi
rm -f "$FIXTURE" "$HOME/.claude/checkpoints/archetype-cache.json"

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

# Count lines starting with "  - " in the skill block (between 🛠 marker and Always-on marker)
SKILL_COUNT=$(echo "$CTX" | awk '/🛠 Likely-useful skills/,/Always-on \(severity/' | grep -cE '^[[:space:]]+- ')

if [ "$SKILL_COUNT" -gt 10 ]; then
  echo "FAIL: skill block has $SKILL_COUNT entries, expected ≤10. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Alphabetical sort: first listed skill should be lll-skill (smallest alphabetically of the 15 fixture entries)
FIRST=$(echo "$CTX" | awk '/🛠 Likely-useful skills/,/Always-on \(severity/' | grep -E '^[[:space:]]+- ' | head -1)
if ! echo "$FIRST" | grep -qE 'lll-skill'; then
  echo "FAIL: expected 'lll-skill' as first alphabetical entry, got: $FIRST" >&2
  exit 1
fi

echo "PASS"
