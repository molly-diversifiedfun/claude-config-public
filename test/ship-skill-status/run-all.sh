#!/bin/bash
# ship-skill-status.py: reports fired vs expected skills per scope.
set -e
SCRIPT="$HOME/.claude/scripts/ship-skill-status.py"

# 01 — kill switch
OUT=$(SHIP_SKILL_STATUS=off python3 "$SCRIPT")
echo "$OUT" | grep -q "disabled" || { echo "01-kill-switch: FAIL"; exit 1; }
echo "01-kill-switch: OK"

# 02 — no active .ship/<run>/ → informational message, exit 0
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
OUT=$(SHIP_SKILL_STATUS_RUN_DIR="/nonexistent" python3 "$SCRIPT")
echo "$OUT" | grep -qi "no active /ship run" || { echo "02-no-run: FAIL — got: $OUT"; exit 1; }
echo "02-no-run: OK"

# 03 — scope=M with NO invocations → all expected skills marked pending
mkdir -p "$TMP/run-empty"
echo '{"scope":"M","rationale":"test"}' > "$TMP/run-empty/scope.json"
OUT=$(SHIP_SKILL_STATUS_RUN_DIR="$TMP/run-empty" python3 "$SCRIPT")
echo "$OUT" | grep -qE 'Scope:\*\*\s*M' || { echo "03-empty: FAIL — scope not reported: $OUT"; exit 1; }
echo "$OUT" | grep -qE 'Expected skills:\*\*\s*5' || { echo "03-empty: FAIL — wrong expected count: $OUT"; exit 1; }
PENDING_COUNT=$(echo "$OUT" | grep -c "⏳ pending" || true)
[ "$PENDING_COUNT" -eq 5 ] || { echo "03-empty: FAIL — expected 5 pending, got $PENDING_COUNT"; exit 1; }
echo "03-empty-all-pending: OK"

# 04 — scope=M with 3 invocations fired → 3 ✅, 2 pending
mkdir -p "$TMP/run-partial"
echo '{"scope":"M","rationale":"test"}' > "$TMP/run-partial/scope.json"
cat > "$TMP/run-partial/skills-invoked.log" <<EOF
{"ts":"2026-05-23T13:00:00Z","skill":"superpowers:brainstorming"}
{"ts":"2026-05-23T13:05:00Z","skill":"superpowers:test-driven-development"}
{"ts":"2026-05-23T13:10:00Z","skill":"superpowers:verification-before-completion"}
EOF
OUT=$(SHIP_SKILL_STATUS_RUN_DIR="$TMP/run-partial" python3 "$SCRIPT")
FIRED=$(echo "$OUT" | grep -c "✅" || true)
PENDING=$(echo "$OUT" | grep -c "⏳ pending" || true)
[ "$FIRED" -eq 3 ] || { echo "04-partial: FAIL — expected 3 fired, got $FIRED"; exit 1; }
[ "$PENDING" -eq 2 ] || { echo "04-partial: FAIL — expected 2 pending, got $PENDING"; exit 1; }
echo "04-partial: OK"

# 05 — scope=L with all expected fired → completion banner
mkdir -p "$TMP/run-complete"
echo '{"scope":"L","rationale":"test"}' > "$TMP/run-complete/scope.json"
cat > "$TMP/run-complete/skills-invoked.log" <<EOF
{"ts":"2026-05-23T13:00:00Z","skill":"superpowers:brainstorming"}
{"ts":"2026-05-23T13:01:00Z","skill":"superpowers:writing-plans"}
{"ts":"2026-05-23T13:02:00Z","skill":"superpowers:test-driven-development"}
{"ts":"2026-05-23T13:03:00Z","skill":"superpowers:subagent-driven-development"}
{"ts":"2026-05-23T13:04:00Z","skill":"superpowers:verification-before-completion"}
{"ts":"2026-05-23T13:05:00Z","skill":"superpowers:requesting-code-review"}
{"ts":"2026-05-23T13:06:00Z","skill":"superpowers:finishing-a-development-branch"}
EOF
OUT=$(SHIP_SKILL_STATUS_RUN_DIR="$TMP/run-complete" python3 "$SCRIPT")
echo "$OUT" | grep -q "All 7 expected skills" || { echo "05-complete: FAIL — completion banner missing: $OUT"; exit 1; }
echo "05-complete: OK"

# 06 — extra skills (not in expected set) get their own section
mkdir -p "$TMP/run-extras"
echo '{"scope":"S","rationale":"test"}' > "$TMP/run-extras/scope.json"
cat > "$TMP/run-extras/skills-invoked.log" <<EOF
{"ts":"2026-05-23T13:00:00Z","skill":"superpowers:test-driven-development"}
{"ts":"2026-05-23T13:05:00Z","skill":"superpowers:dispatching-parallel-agents"}
EOF
OUT=$(SHIP_SKILL_STATUS_RUN_DIR="$TMP/run-extras" python3 "$SCRIPT")
echo "$OUT" | grep -q "Extra skills invoked" || { echo "06-extras: FAIL — extras section missing"; exit 1; }
echo "$OUT" | grep -q "dispatching-parallel-agents" || { echo "06-extras: FAIL — extra skill not listed"; exit 1; }
echo "06-extras: OK"

# 07 — advisory only: NEVER exits non-zero
SHIP_SKILL_STATUS_RUN_DIR="/nonexistent" python3 "$SCRIPT" > /dev/null && echo "07-never-blocks: OK"

echo ""
echo "ship-skill-status tests: 7 passed, 0 failed"
