#!/usr/bin/env bash
set +e
SCRIPT="$HOME/.claude/scripts/render-manifest.py"
FIXTURE="$HOME/.claude/test/manifest/fixtures/valid-manifest.yaml"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: render-manifest.py not found"; FAIL=$((FAIL+1))
else
  AGENTS="builder creator product-lead reviewer content-qa"
  MISSING=0
  for a in $AGENTS; do
    MANIFEST_PATH="$FIXTURE" python3 "$SCRIPT" --agent "$a" --to "$TMP" >/dev/null 2>&1
    if [ ! -f "$TMP/$a.md" ]; then
      echo "FAIL: $a.md not rendered"; MISSING=$((MISSING+1)); continue
    fi
    # INVARIANT: frontmatter MUST start at byte 0 with "---". Claude Code's
    # subagent loader drops any file whose first line isn't "---" (a leading
    # HTML comment silently unregisters the agent). The DO-NOT-EDIT header
    # therefore lives in the BODY, not on line 1.
    if [ "$(head -1 "$TMP/$a.md")" != "---" ]; then
      echo "FAIL: $a.md first line is not '---' (frontmatter must start at byte 0)"; MISSING=$((MISSING+1))
    fi
    if ! grep -q "<!-- DO NOT EDIT - generated from agent-skill-manifest.yaml -->" "$TMP/$a.md"; then
      echo "FAIL: $a.md missing DO-NOT-EDIT header in body"; MISSING=$((MISSING+1))
    fi
  done
  if [ "$MISSING" -eq 0 ]; then
    echo "PASS: all 5 agents start with '---' and carry DO-NOT-EDIT header in body"; PASS=$((PASS+1))
  else
    echo "FAIL: $MISSING structural defects across agents"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
