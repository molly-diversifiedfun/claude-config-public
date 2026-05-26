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
  STDERR_LOG="$TMP/render-stderr.log"
  MANIFEST_PATH="$FIXTURE" python3 "$SCRIPT" --agent creator --to "$TMP" >/dev/null 2>"$STDERR_LOG"
  RC=$?
  if [ "$RC" -ne 0 ] || [ ! -f "$TMP/creator.md" ]; then
    echo "FAIL: render did not produce creator.md (rc=$RC)"
    echo "stderr:"; sed 's/^/  /' "$STDERR_LOG"
    FAIL=$((FAIL+1))
  else
    # Canonical format: chain skills live in the markdown body, not nested YAML frontmatter.
    # Look for the "## Chain skills" section AND humanize-ai-writing as a body bullet.
    if grep -q "^## Chain skills" "$TMP/creator.md" && grep -q "^- humanize-ai-writing$" "$TMP/creator.md"; then
      echo "PASS: chain skills body section contains humanize-ai-writing"; PASS=$((PASS+1))
    else
      echo "FAIL: chain section missing or no humanize-ai-writing"; cat "$TMP/creator.md"; FAIL=$((FAIL+1))
    fi
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
