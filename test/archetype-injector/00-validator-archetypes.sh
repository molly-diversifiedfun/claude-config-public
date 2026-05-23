#!/usr/bin/env bash
# Test: validator accepts learned-pattern files with `archetypes: [...]` field.
set -euo pipefail

VALIDATOR="$HOME/.claude/scripts/validate-frontmatter.sh"
TMP=$(mktemp -t archetype-test.XXXXXX)
mv "$TMP" "$TMP.md"
TMP="$TMP.md"
trap "rm -f '$TMP'" EXIT

cat > "$TMP" <<'EOF'
---
name: test-pattern
description: A test pattern for archetypes validation.
type: learned-pattern
applies-to: [test]
projects: [all]
severity: warning
phase: [build]
last-validated: 2026-05-20
archetypes: [web-app, telegram-bot]
---
# Pattern
Body.
EOF

OUT=$("$VALIDATOR" "$TMP" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: validator rejected file with valid archetypes field: $OUT" >&2
  exit 1
fi

# Test invalid archetype value
cat > "$TMP" <<'EOF'
---
name: test-pattern
description: A test pattern.
type: learned-pattern
applies-to: [test]
projects: [all]
severity: warning
phase: [build]
last-validated: 2026-05-20
archetypes: [bogus-archetype]
---
# Body
EOF

OUT=$("$VALIDATOR" "$TMP" 2>&1) && RC=0 || RC=$?

if [ $RC -eq 0 ]; then
  echo "FAIL: validator accepted invalid archetype 'bogus-archetype': $OUT" >&2
  exit 1
fi

# Block-list shape must be rejected
cat > "$TMP" <<'EOF'
---
name: test-pattern
description: A test pattern.
type: learned-pattern
applies-to: [test]
projects: [all]
severity: warning
phase: [build]
last-validated: 2026-05-20
archetypes:
  - web-app
  - telegram-bot
---
# Body
EOF

OUT=$("$VALIDATOR" "$TMP" 2>&1) && RC=0 || RC=$?
if [ $RC -eq 0 ]; then
  echo "FAIL: validator accepted block-list archetypes (should require inline-array): $OUT" >&2
  exit 1
fi

# Empty inline-array passes (no values to vocabulary-check)
cat > "$TMP" <<'EOF'
---
name: test-pattern
description: A test pattern.
type: learned-pattern
applies-to: [test]
projects: [all]
severity: warning
phase: [build]
last-validated: 2026-05-20
archetypes: []
---
# Body
EOF

OUT=$("$VALIDATOR" "$TMP" 2>&1)
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: validator rejected empty archetypes []: $OUT" >&2
  exit 1
fi

# Single-item inline-array
cat > "$TMP" <<'EOF'
---
name: test-pattern
description: A test pattern.
type: learned-pattern
applies-to: [test]
projects: [all]
severity: warning
phase: [build]
last-validated: 2026-05-20
archetypes: [always-on]
---
# Body
EOF

OUT=$("$VALIDATOR" "$TMP" 2>&1)
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: validator rejected single-item archetypes: $OUT" >&2
  exit 1
fi

echo "PASS"
