#!/bin/bash
# test-ship-phase-gate.sh — fixture tests for ship-phase-gate.sh
# Usage: test-ship-phase-gate.sh
# Exit 0 = all pass. Exit 1 = ≥1 fail.
#
# NOTE: Tests run sequentially and SHARE the $WORK directory state.
# Each test builds on prior fixtures. To run tests in isolation, refactor
# to a setup_each() helper and call it before each test.

set -e
HOOK="$HOME/.claude/hooks/ship-phase-gate.sh"
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK" >&2; exit 1; }

PASS=0; FAIL=0
check() {
  local name="$1" want="$2" got="$3"
  if echo "$got" | grep -q "$want"; then
    PASS=$((PASS+1)); echo "PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "FAIL: $name — wanted '$want', got '$got'"
  fi
}

# Setup temp workspace
WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT
cd "$WORK"

# Test 1: no .ship dir → exit 0, no output
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "no .ship dir → silent pass" "^$" "$RES"

# Test 2: .ship dir but no deploy-log.md → exit 0
mkdir -p .ship/2026-05-10-test/
cat > .ship/2026-05-10-test/patterns.md <<'PATTERNS'
# Patterns for test
PATTERNS
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "no deploy-log.md → silent pass" "^$" "$RES"

# Test pre-3a: deploy-log exists with NO ## Deploy attempt sections → silent pass.
# This catches Bug 1 (stderr noise from `0\n0` integer compare) AND verifies
# pre-deploy state is silent (observability/smoke checks gated on DEPLOY_COUNT > 0).
cat > .ship/2026-05-10-test/deploy-log.md <<'LOG'
# Deploy log: test feature
LOG
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "empty deploy-log → silent pass (Bug 1 regression)" "^$" "$RES"

# Test 3: deploy-log.md with 3 attempts, no pivot → BLOCK
cat > .ship/2026-05-10-test/deploy-log.md <<'LOG'
# Deploy log: test

## Deploy attempt 1
result: fail

## Deploy attempt 2
result: fail

## Deploy attempt 3
result: fail
LOG
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "3 deploys + no pivot → block" '"decision":"block"' "$RES"
check "3-deploy-rule reason in output" "3-deploy rule triggered" "$RES"

# Test 4: 3 deploys WITH pivot → no block on 3-deploy rule, but warn on missing observability
cat >> .ship/2026-05-10-test/deploy-log.md <<'LOG'

## Pivot decision
Switching from openclaw to grammY.
LOG
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "pivot present → no block" '"decision":"warn"' "$RES"
check "missing observability warned" "Observability declaration" "$RES"

# Test 5: observability present, smoke missing → warn on smoke
cat >> .ship/2026-05-10-test/deploy-log.md <<'LOG'

## Observability: Railway logs visible + Sentry breadcrumbs
LOG
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "missing smoke warned" "Smoke test section" "$RES"

# Test 6: full happy path → silent pass
cat >> .ship/2026-05-10-test/deploy-log.md <<'LOG'

## Smoke test: PASS
e2e-runner verified /webhook
LOG
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "happy path → silent pass" "^$" "$RES"

# Test 7: ancestor traversal — cwd is 3 levels below .ship parent → must still fire
mkdir -p src/components/widget/
# Note: WORK already has .ship/2026-05-10-test/ from test 1; we use same dir
# but cd into a deep subtree, hook must still find .ship/ in WORK
ORIG_WORK="$WORK"
cd "$WORK/src/components/widget/"
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
cd "$ORIG_WORK"
check "ancestor traversal from src/components/widget/" "^$" "$RES"
# This tests: deploy-log has all required sections (set up by test 6), so hook
# must walk up 3 levels (widget→components→src→WORK) to find .ship and pass silently

# Test post-7: multi-run, lexicographic sort picks newest by name.
# Add an OLDER run that would block (3 deploys, no pivot). The active run
# (2026-05-10-test) is in happy state, so hook must pick it and pass silent.
mkdir -p .ship/2026-05-09-old/
touch .ship/2026-05-09-old/patterns.md
cat > .ship/2026-05-09-old/deploy-log.md <<'LOG'
## Deploy attempt 1
## Deploy attempt 2
## Deploy attempt 3
LOG
RES=$(echo '{"tool_name":"Agent"}' | "$HOOK" 2>&1 || true)
check "multi-run picks newest by name (silent on happy run)" "^$" "$RES"

echo ""
echo "RESULT: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
