#!/bin/bash
# Scope inheritance: if `.ship/<run>/scope.json` is present and fresh in
# SHIP_SCOPE_INHERIT_DIR, return its scope without calling Haiku.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Mock claude that we should NOT hit when inheritance succeeds — if hit, fail loudly
cat > "$TMP/claude" <<'EOF'
#!/bin/bash
# This mock should never be called when inheritance fires. If we are called,
# the test should fail (returning a scope that the assertion expects DIFFERENT
# from what inheritance returns lets us detect the leak).
INNER='{"scope":"S","rationale":"MOCK CALLED — inheritance did not fire"}'
printf '{"type":"result","result":%s}\n' "$(echo "$INNER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
EOF
chmod +x "$TMP/claude"
export SHIP_SCOPE_CLAUDE_CMD="$TMP/claude"

# ── 1. Fresh scope.json exists → inherit, no Haiku call ──
mkdir -p "$TMP/inherit/.ship/run-foo"
echo '{"scope":"L","rationale":"original L pick"}' > "$TMP/inherit/.ship/run-foo/scope.json"

OUT=$(SHIP_SCOPE_INHERIT_DIR="$TMP/inherit" python3 ~/.claude/scripts/ship-scope-classify.py "lets do step 5 build")
echo "$OUT" | grep -q '"scope": "L"' || { echo "07a-inherit-L: FAIL — expected L, got: $OUT"; exit 1; }
echo "$OUT" | grep -q "inherited from" || { echo "07a-inherit-L: FAIL — expected 'inherited from' rationale: $OUT"; exit 1; }
echo "07a-inherit-fresh-L: OK"

# ── 2. Most-recent scope.json wins when multiple exist ──
mkdir -p "$TMP/inherit2/.ship/old-run" "$TMP/inherit2/.ship/new-run"
echo '{"scope":"S","rationale":"old"}' > "$TMP/inherit2/.ship/old-run/scope.json"
touch -t 202001010000 "$TMP/inherit2/.ship/old-run/scope.json"  # ancient
echo '{"scope":"XL","rationale":"recent"}' > "$TMP/inherit2/.ship/new-run/scope.json"  # mtime = now

OUT=$(SHIP_SCOPE_INHERIT_DIR="$TMP/inherit2" python3 ~/.claude/scripts/ship-scope-classify.py "pick it back up")
echo "$OUT" | grep -q '"scope": "XL"' || { echo "07b-most-recent-wins: FAIL — expected XL, got: $OUT"; exit 1; }
echo "07b-most-recent-wins: OK"

# ── 3. Stale scope.json (>7 days old) → ignored, Haiku called ──
mkdir -p "$TMP/inherit3/.ship/stale-run"
echo '{"scope":"L","rationale":"stale L"}' > "$TMP/inherit3/.ship/stale-run/scope.json"
touch -t 202401010000 "$TMP/inherit3/.ship/stale-run/scope.json"  # ancient

OUT=$(SHIP_SCOPE_INHERIT_DIR="$TMP/inherit3" python3 ~/.claude/scripts/ship-scope-classify.py "lets do step 5 build")
# Mock returns S w/ "MOCK CALLED" rationale; that confirms Haiku path fired
echo "$OUT" | grep -q '"scope": "S"' || { echo "07c-stale-ignored: FAIL — expected S from mock, got: $OUT"; exit 1; }
echo "$OUT" | grep -q "MOCK CALLED" || { echo "07c-stale-ignored: FAIL — expected mock to fire, got: $OUT"; exit 1; }
echo "07c-stale-scope-ignored: OK"

# ── 4. No .ship/ dir at all → Haiku called as before ──
OUT=$(SHIP_SCOPE_INHERIT_DIR="$TMP/empty" python3 ~/.claude/scripts/ship-scope-classify.py "do something")
echo "$OUT" | grep -q "MOCK CALLED" || { echo "07d-no-ship-dir: FAIL — expected mock to fire: $OUT"; exit 1; }
echo "07d-no-ship-dir: OK"

echo ""
echo "07-scope-inheritance: 4/4 OK"
