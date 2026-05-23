#!/bin/bash
# /ship preflight: probe cmd / env / file / url deps, render markdown report.
set -e
SCRIPT="$HOME/.claude/scripts/ship-preflight.py"

# 01 — kill switch
OUT=$(SHIP_PREFLIGHT=off python3 "$SCRIPT" < /dev/null)
echo "$OUT" | grep -q "disabled" || { echo "01-kill-switch: FAIL"; exit 1; }
echo "01-kill-switch: OK"

# 02 — cmd probe: passes for git, fails for nonexistent
OUT=$(printf "cmd:git\ncmd:nonexistent-tool-xyz-99\n" | python3 "$SCRIPT")
echo "$OUT" | grep -qE 'cmd:git.*✅' || { echo "02-cmd-probe: FAIL — git should pass: $OUT"; exit 1; }
echo "$OUT" | grep -qE 'nonexistent-tool-xyz-99.*❌' || { echo "02-cmd-probe: FAIL — nonexistent should fail: $OUT"; exit 1; }
echo "02-cmd-probe: OK"

# 03 — env probe: passes for HOME, fails for unset
OUT=$(printf "env:HOME\nenv:DEFINITELY_NOT_SET_XYZ123\n" | python3 "$SCRIPT")
echo "$OUT" | grep -qE 'env:HOME.*✅' || { echo "03-env-probe: FAIL — HOME should pass"; exit 1; }
echo "$OUT" | grep -qE 'DEFINITELY_NOT_SET_XYZ123.*❌' || { echo "03-env-probe: FAIL — unset should fail"; exit 1; }
echo "03-env-probe: OK"

# 04 — file probe: passes for existing, fails for missing
TMP=$(mktemp)
trap "rm -f $TMP" EXIT
OUT=$(printf "file:$TMP\nfile:/nonexistent/missing/path\n" | python3 "$SCRIPT")
echo "$OUT" | grep -qE "file:$TMP.*✅" || { echo "04-file-probe: FAIL — existing should pass"; exit 1; }
echo "$OUT" | grep -qE 'file:/nonexistent/missing/path.*❌' || { echo "04-file-probe: FAIL — missing should fail"; exit 1; }
echo "04-file-probe: OK"

# 05 — comment/blank lines skipped, unknown prefix rejected
OUT=$(printf "\n# a comment\nbogus:thing\n" | python3 "$SCRIPT")
echo "$OUT" | grep -qE 'bogus:thing.*❌' || { echo "05-input-handling: FAIL — unknown prefix should fail"; exit 1; }
# Comments shouldn't appear as rows
echo "$OUT" | grep -q "a comment" && { echo "05-input-handling: FAIL — comment leaked into report"; exit 1; }
echo "05-input-handling: OK"

# 06 — exits 0 even when probes fail (warning, not block)
printf "cmd:nonexistent-fail-xyz\n" | python3 "$SCRIPT" > /dev/null
echo "06-fail-but-exit-zero: OK"

# 07 — reads .ship/<run>/preflight-deps.txt via SHIP_PREFLIGHT_RUN_DIR override
TMP2=$(mktemp -d)
trap "rm -rf $TMP2" EXIT
echo "cmd:git" > "$TMP2/preflight-deps.txt"
OUT=$(SHIP_PREFLIGHT_RUN_DIR="$TMP2" python3 "$SCRIPT")
echo "$OUT" | grep -qE "Source:.*preflight-deps.txt" || { echo "07-run-dir-override: FAIL — source not detected: $OUT"; exit 1; }
test -f "$TMP2/preflight.json" || { echo "07-run-dir-override: FAIL — JSON output not written"; exit 1; }
echo "07-run-dir-override: OK"

echo ""
echo "ship-preflight tests: 7 passed, 0 failed"
