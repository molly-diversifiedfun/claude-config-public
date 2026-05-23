#!/usr/bin/env bash
# Test: _cache_key() is order-independent; cache JSONL roundtrip via env-var override.
# Uses --cache-key debug flag (prints key for two SKILL.md paths) and --cache-dump (prints cache entries).
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/alpha" "$TMP/user/beta"
cat > "$TMP/user/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: alpha desc
---
alpha body text here
EOF
cat > "$TMP/user/beta/SKILL.md" <<'EOF'
---
name: beta
description: beta desc
---
beta body text here
EOF

# Key in s1=alpha, s2=beta order
KEY_AB=$(python3 "$SCRIPT" --cache-key "$TMP/user/alpha/SKILL.md" "$TMP/user/beta/SKILL.md" 2>/dev/null)
RC1=$?

# Key in reverse order
KEY_BA=$(python3 "$SCRIPT" --cache-key "$TMP/user/beta/SKILL.md" "$TMP/user/alpha/SKILL.md" 2>/dev/null)
RC2=$?

if [ "$RC1" -eq 0 ] && [ "$RC2" -eq 0 ]; then echo "PASS: --cache-key exits 0"; PASS=$((PASS+1))
else echo "FAIL: --cache-key exit codes ($RC1, $RC2)"; FAIL=$((FAIL+1)); fi

if [ -n "$KEY_AB" ] && [ "$KEY_AB" = "$KEY_BA" ]; then
  echo "PASS: cache key order-independent ($KEY_AB)"; PASS=$((PASS+1))
else echo "FAIL: cache key not order-independent. AB=$KEY_AB, BA=$KEY_BA"; FAIL=$((FAIL+1)); fi

# Cache JSONL roundtrip: seed a verdict, then dump cache, assert lookup works
CACHE="$TMP/cache.jsonl"
cat > "$CACHE" <<EOF
{"key":"$KEY_AB","name_a":"alpha","name_b":"beta","overlap":true,"confidence":5,"rationale":"test rationale","judge_status":"ok","ts":"2026-05-22T00:00:00Z","model":"claude-haiku-4-5-20251001"}
EOF

DUMP=$(JUDGE_CACHE_FILE="$CACHE" python3 "$SCRIPT" --cache-dump 2>/dev/null)
RC3=$?

if [ "$RC3" -eq 0 ]; then echo "PASS: --cache-dump exits 0"; PASS=$((PASS+1))
else echo "FAIL: --cache-dump exit $RC3"; FAIL=$((FAIL+1)); fi

if echo "$DUMP" | grep -q "$KEY_AB" && echo "$DUMP" | grep -q "test rationale"; then
  echo "PASS: cache lookup returns seeded verdict"; PASS=$((PASS+1))
else echo "FAIL: cache lookup didn't return seeded data. Got: $DUMP"; FAIL=$((FAIL+1)); fi

echo "Test 12: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
