#!/bin/bash
# Phase 8.0.3 Stage 10 doc-update warning: fires when .ship/<run>/scope.json
# exists with scope != S AND the staged set lacks HANDOFF.md / CLAUDE.md.
set -e
HOOK="$HOME/.claude/hooks/pre-commit-checks.sh"

setup_repo() {
  TMP=$(mktemp -d)
  cd "$TMP"
  git init -q
  git config user.email "x@y"
  git config user.name "test"
  # Initial commit so we have a HEAD
  echo "init" > README.md && git add README.md && git commit -q -m "init"
}
cleanup() { cd - >/dev/null 2>&1; rm -rf "$TMP"; }

run_hook() {
  echo "{\"tool_input\":{\"command\":\"$1\"}}" | bash "$HOOK" 2>&1
}

# ── 1. No /ship run active → no Stage 10 warning ──
setup_repo
echo "x" > foo.ts && git add foo.ts
OUT=$(run_hook "git commit -m feat: x")
echo "$OUT" | grep -q "Stage 10" && { echo "01a-no-ship-run: FAIL — warning fired without scope.json: $OUT"; cleanup; exit 1; }
echo "01a-no-ship-run: OK"
cleanup

# ── 2. /ship scope=S → no Stage 10 warning (S exempt) ──
setup_repo
mkdir -p .ship/foo && echo '{"scope":"S","rationale":"fix"}' > .ship/foo/scope.json
echo "x" > foo.ts && git add foo.ts
OUT=$(run_hook "git commit -m fix: typo")
echo "$OUT" | grep -q "Stage 10" && { echo "01b-scope-S-exempt: FAIL: $OUT"; cleanup; exit 1; }
echo "01b-scope-S-exempt: OK"
cleanup

# ── 3. /ship scope=M + no HANDOFF/CLAUDE staged → warning ──
setup_repo
mkdir -p .ship/foo && echo '{"scope":"M","rationale":"feature"}' > .ship/foo/scope.json
echo "x" > foo.ts && git add foo.ts
OUT=$(run_hook "git commit -m feat: x")
echo "$OUT" | grep -q "Stage 10: scope=M expects HANDOFF" || { echo "01c-warn-no-handoff: FAIL: $OUT"; cleanup; exit 1; }
echo "$OUT" | grep -q "Stage 10: scope=M expects CLAUDE" || { echo "01c-warn-no-claude: FAIL: $OUT"; cleanup; exit 1; }
echo "01c-scope-M-missing-docs: OK"
cleanup

# ── 4. /ship scope=M + HANDOFF + CLAUDE staged → silent ──
setup_repo
mkdir -p .ship/foo && echo '{"scope":"M","rationale":"feature"}' > .ship/foo/scope.json
echo "x" > foo.ts && echo "h" > HANDOFF.md && echo "c" > CLAUDE.md
git add foo.ts HANDOFF.md CLAUDE.md
OUT=$(run_hook "git commit -m feat: x")
echo "$OUT" | grep -q "Stage 10" && { echo "01d-docs-present-silent: FAIL: $OUT"; cleanup; exit 1; }
echo "01d-docs-present-silent: OK"
cleanup

# ── 5. docs: commit exempt even with scope=M ──
setup_repo
mkdir -p .ship/foo && echo '{"scope":"M","rationale":"feature"}' > .ship/foo/scope.json
echo "x" > foo.ts && git add foo.ts
OUT=$(run_hook "git commit -m docs: tweak")
echo "$OUT" | grep -q "Stage 10" && { echo "01e-docs-commit-exempt: FAIL: $OUT"; cleanup; exit 1; }
echo "01e-docs-commit-exempt: OK"
cleanup

echo ""
echo "pre-commit-checks Stage 10 tests: 5 passed, 0 failed"
