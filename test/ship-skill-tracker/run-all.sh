#!/bin/bash
# ship-skill-tracker.sh: appends Skill invocations to .ship/<run>/skills-invoked.log
# when a /ship run is active. Silent otherwise. Never blocks.
set -e
HOOK="$HOME/.claude/hooks/ship-skill-tracker.sh"

# 01 — kill switch
OUT=$(SHIP_SKILL_TRACK=off bash "$HOOK" < /dev/null)
[ -z "$OUT" ] || { echo "01-kill-switch: FAIL — expected empty, got: $OUT"; exit 1; }
echo "01-kill-switch: OK"

# 02 — no .ship/ dir → silent no-op
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"
OUT=$(echo '{"tool_input":{"skill":"superpowers:tdd"}}' | bash "$HOOK")
[ -z "$OUT" ] || { echo "02-no-ship-dir: FAIL — expected silent, got: $OUT"; exit 1; }
echo "02-no-ship-dir: OK"

# 03 — active /ship run → invocation logged to skills-invoked.log
mkdir -p .ship/active-run
echo '{"scope":"M","rationale":"test"}' > .ship/active-run/scope.json
echo '{"tool_input":{"skill":"superpowers:brainstorming"}}' | bash "$HOOK"
[ -f .ship/active-run/skills-invoked.log ] || { echo "03-active-ship: FAIL — log not created"; exit 1; }
grep -q "superpowers:brainstorming" .ship/active-run/skills-invoked.log || { echo "03-active-ship: FAIL — skill not in log"; exit 1; }
grep -q '"ts":"20' .ship/active-run/skills-invoked.log || { echo "03-active-ship: FAIL — timestamp missing"; exit 1; }
echo "03-active-ship: OK"

# 04 — multiple invocations append (don't overwrite)
echo '{"tool_input":{"skill":"superpowers:test-driven-development"}}' | bash "$HOOK"
COUNT=$(wc -l < .ship/active-run/skills-invoked.log | tr -d ' ')
[ "$COUNT" -eq 2 ] || { echo "04-append: FAIL — expected 2 lines, got $COUNT"; exit 1; }
echo "04-append: OK"

# 05 — non-Skill events ignored (no .tool_input.skill field)
echo '{"tool_input":{"command":"ls"}}' | bash "$HOOK"
COUNT2=$(wc -l < .ship/active-run/skills-invoked.log | tr -d ' ')
[ "$COUNT2" -eq 2 ] || { echo "05-ignore-non-skill: FAIL — expected still 2 lines, got $COUNT2"; exit 1; }
echo "05-ignore-non-skill: OK"

# 06 — empty stdin → silent (no crash)
OUT=$(bash "$HOOK" < /dev/null)
[ -z "$OUT" ] || { echo "06-empty-stdin: FAIL"; exit 1; }
echo "06-empty-stdin: OK"

# 07 — never exits non-zero (advisory, soft-fail-open)
echo "garbage not json" | bash "$HOOK" && echo "07-soft-fail-open: OK"

echo ""
echo "ship-skill-tracker tests: 7 passed, 0 failed"
