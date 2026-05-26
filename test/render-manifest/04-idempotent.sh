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
  mkdir -p "$TMP/a" "$TMP/b"
  STDERR_A="$TMP/render-stderr-a.log"
  STDERR_B="$TMP/render-stderr-b.log"
  MANIFEST_PATH="$FIXTURE" python3 "$SCRIPT" --agent builder --to "$TMP/a" >/dev/null 2>"$STDERR_A"
  MANIFEST_PATH="$FIXTURE" python3 "$SCRIPT" --agent builder --to "$TMP/b" >/dev/null 2>"$STDERR_B"
  if [ ! -f "$TMP/a/builder.md" ] || [ ! -f "$TMP/b/builder.md" ]; then
    echo "FAIL: render did not produce both builder.md files"
    echo "stderr (a):"; sed 's/^/  /' "$STDERR_A"
    echo "stderr (b):"; sed 's/^/  /' "$STDERR_B"
    FAIL=$((FAIL+1))
  else
    HA=$(shasum -a 256 "$TMP/a/builder.md" | awk '{print $1}')
    HB=$(shasum -a 256 "$TMP/b/builder.md" | awk '{print $1}')
    if [ "$HA" = "$HB" ]; then
      echo "PASS: render is idempotent ($HA)"; PASS=$((PASS+1))
    else
      echo "FAIL: hashes differ ($HA vs $HB)"; FAIL=$((FAIL+1))
    fi
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
