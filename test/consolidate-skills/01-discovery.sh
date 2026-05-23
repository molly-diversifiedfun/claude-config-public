#!/usr/bin/env bash
# Test: discovery finds user + plugin skills, annotates source correctly.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture: 2 user skills + 1 plugin skill
mkdir -p "$TMP/user/alpha"
cat > "$TMP/user/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: First user skill for testing
---
body
EOF

mkdir -p "$TMP/user/bravo"
cat > "$TMP/user/bravo/SKILL.md" <<'EOF'
---
name: bravo
description: Second user skill for testing
---
body
EOF

mkdir -p "$TMP/plugin-cache/myplugin/1.0.0/skills/charlie"
cat > "$TMP/plugin-cache/myplugin/1.0.0/skills/charlie/SKILL.md" <<'EOF'
---
name: charlie
description: Plugin-installed skill for testing
---
body
EOF

# Run with discover-only mode (--discover-only prints "name | source" per skill)
OUT=$(SKILL_CONSOLIDATE_ROOTS="$TMP/user:$TMP/plugin-cache" \
      python3 "$SCRIPT" --discover-only 2>/dev/null)
RC=$?

# Assertion 1: exit 0
if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

# Assertion 2: alpha annotated [user]
if echo "$OUT" | grep -q '^alpha | \[user\]'; then echo "PASS: alpha [user]"; PASS=$((PASS+1))
else echo "FAIL: alpha annotation. Got: $OUT"; FAIL=$((FAIL+1)); fi

# Assertion 3: bravo annotated [user]
if echo "$OUT" | grep -q '^bravo | \[user\]'; then echo "PASS: bravo [user]"; PASS=$((PASS+1))
else echo "FAIL: bravo annotation. Got: $OUT"; FAIL=$((FAIL+1)); fi

# Assertion 4: charlie annotated [plugin:myplugin]
if echo "$OUT" | grep -q '^charlie | \[plugin:myplugin\]'; then echo "PASS: charlie [plugin:myplugin]"; PASS=$((PASS+1))
else echo "FAIL: charlie annotation. Got: $OUT"; FAIL=$((FAIL+1)); fi

echo "Test 01: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
