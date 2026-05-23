---
name: bash-discipline
description: Bash gotchas that silently break shell hooks and scripts — $? capture order, ${VAR:+} non-empty trap, bash 3.2 limits, pipe env scope. Read before editing any ~/.claude/hooks/* or ~/.claude/scripts/* file.
type: learned-pattern
applies-to: [infra, hook, process, shell-scripting]
projects: [all]
severity: warning
phase: [build, deploy]
trigger: [bash-authoring, hook-edit, shell-script-debug]
last-validated: 2026-05-20
archetypes: [infra-config]
---

# Pattern: Bash Discipline

Bash 3.2 ships by default on macOS (Apple won't bundle a GPLv3 newer bash), and the shebang `#!/usr/bin/env bash` resolves to it. Many of these gotchas exist because shell substitutions look intuitive and behave differently. All four patterns below caused silent failures in shipped hooks before being caught — write defensive bash from the start.

## `$?` resets on command substitution — capture exit code FIRST

`$?` reflects the most-recent foreground command. Any command substitution between the operation and the read — including `$(date)` inside an echo — resets `$?` to 0 before you read it.

```bash
# WRONG — `date` resets $? before echo reads it
mempalace mine "$DIR" >> "$LOG" 2>&1
if [ $? -ne 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAIL exit=$?" >> "$LOG"  # exit=0, always
fi

# RIGHT — capture to a variable immediately
mempalace mine "$DIR" >> "$LOG" 2>&1
RC=$?                                  # FIRST line after the command
TS=$(date '+%Y-%m-%d %H:%M:%S')        # now safe — RC already captured
if [ $RC -ne 0 ]; then
  echo "[$TS] FAIL exit=$RC" >> "$LOG"
fi
```

ANY command in the format line (`date`, `basename`, `dirname`, even `[`) resets `$?`. The rule: if you care about an exit code, copy it to a named variable on the line directly after the command. Everything else reads the variable.

**Where this hides:** hook scripts, deploy wrappers, retry loops, error formatters. Anywhere "log the failure with timestamp and details" appears. Caught in `~/.claude/hooks/mempalace-wrapper.sh:128-129` 2026-05-19 — Wave 3 logged 39 stale `exit=0` entries before the fix. (workspace/feedback_bash_dollar_question_capture_order.md)

## `${VAR:+ value}` does not honor "0" as falsy

`${VAR:+ ...}` expands when VAR is set AND non-empty. The string "0" is non-empty, so `:+` always expands. Mixing `${VAR:-0}` defaults with `${VAR:+...}` formatting is buggy by construction.

```bash
# WRONG — banner shows (DRY_RUN) on every run, including real ones
DRY_RUN="${DRY_RUN:-0}"
echo "=== mempalace-bulk-load${DRY_RUN:+ (DRY_RUN)} ==="   # always expands

# RIGHT — explicit boolean check
DRY_RUN="${DRY_RUN:-0}"
LABEL=""
if [ "$DRY_RUN" = "1" ]; then LABEL=" (DRY_RUN)"; fi
echo "=== mempalace-bulk-load${LABEL} ==="
```

`:+` cares about set + non-empty, not truthiness. `{"0","false","no","",""1"}` collapses under `:+` to two buckets: `""` (don't expand) and everything else (expand).

Either:
- Use `${VAR:-}` (default to empty) so `:+` works as a boolean.
- Or use explicit `[ "$VAR" = "1" ]` and don't lean on `:+` for formatting.

**Where this hides:** banner / log-prefix formatting, optional CLI flag pass-through, debug-mode toggles in wrappers. Caught in `~/.claude/scripts/mempalace-bulk-load.sh:77-79` 2026-05-19. (workspace/feedback_bash_var_plus_default_nonempty_gotcha.md)

## bash 3.2 has no associative arrays, no `${var^^}`, no `mapfile`, no `wait -n`

macOS default bash is 3.2. Many features look like core bash but are 4+ only. They fail with errors that look like minor syntax issues but actually mean "this language construct doesn't exist here."

```bash
# WRONG on macOS — silently produces empty array
declare -A PATTERNS=(
  [plan]='\b(brainstorm|...)\b'
  [build]='\b(implement|...)\b'
)
if echo "$PROMPT" | grep -qE "${PATTERNS[plan]}"; then ...

# Error to stderr: "declare: -A: invalid option"
# Script continues under `set +e`. PATTERNS is empty. Every lookup returns "".
```

```bash
# RIGHT on bash 3.2 — case statement covers the same shape
for wt in plan build debug review; do
  case "$wt" in
    plan)  PAT='\b(brainstorm|...)\b' ;;
    build) PAT='\b(implement|...)\b' ;;
    debug) PAT='\b(debug|...)\b' ;;
    review) PAT='\b(review|...)\b' ;;
  esac
  if echo "$PROMPT" | grep -qE "$PAT"; then
    MATCH="$wt"
    break
  fi
done
```

**Bash 4+ features unavailable in default macOS bash:**
- `declare -A` (associative arrays) — use case statements or parallel arrays
- `${var^^}` / `${var,,}` (case conversion) — use `tr '[:lower:]' '[:upper:]'`
- `mapfile` / `readarray` — use `while IFS= read -r line; do ... done < file`
- `${arr[@]: -n}` (negative offsets) — compute index explicitly
- `wait -n` (any-job wait) — use explicit PID list with `wait $pid1 $pid2`
- Lastpipe, nameref (`declare -n`), `local -n`

**Where this hides:** any hook that "should be portable bash" — Linux CI sees bash 4+, macOS dev sees bash 3.2, hook silently produces empty output on the dev box. Symptom: `set +e` swallows the error, the test that should catch it does `OUT=$(... 2>&1)` and chokes on the error string in the output capture. Caught in Phase 7.1.5 work-type detection 2026-05-20. (workspace/feedback_bash_3_2_declare_assoc_array_unsupported.md)

## Pipe env-var scope — the assignment binds to the COMMAND it precedes

`VAR=value cmd1 | cmd2` sets VAR for cmd1's process only. cmd2 runs in a separate process and doesn't see VAR. This bites multi-line `awk ENVIRON` patterns hard because the workaround for missing `awk -v` newline support is to use ENVIRON — but ENVIRON only sees variables in awk's own environment.

```bash
# WRONG — VAR set on printf, not awk; awk's ENVIRON is empty
VAR="$WORK_TYPE_BLOCK" printf '%s' "$base" | awk '
  /pattern/ { print ENVIRON["VAR"] }   # prints empty string
  { print }
'

# RIGHT — VAR set on the awk command (right side of pipe)
printf '%s' "$base" | VAR="$WORK_TYPE_BLOCK" awk '
  /pattern/ { print ENVIRON["VAR"] }   # prints WORK_TYPE_BLOCK content
  { print }
'

# Also right — export first, valid for both sides
export VAR="$WORK_TYPE_BLOCK"
printf '%s' "$base" | awk '/pattern/ { print ENVIRON["VAR"] }'
```

The trap is reading left-to-right and assuming "VAR is in scope for the whole pipeline." It isn't — `cmd1 | cmd2` forks two processes; only the immediately-preceding command gets the inline assignment.

**Why ENVIRON not `-v`:** awk's `-v` parameter doesn't carry newlines. If you need to pass multi-line content to awk, use ENVIRON. (Or write a temp file; or escape newlines manually.) Caught in Phase 7.1.5.1 cache-pollution fix 2026-05-20.

## `grep -c` / `grep -vc` exit-code overload — `cmd || fallback` traps when count is 0

`grep -c` (count matches) and `grep -vc` (count inverse-matches) overload the exit code with the result: exit 0 if count > 0, exit 1 if count == 0, exit 2 on real error. Pairing them with `|| fallback` for "default on error" is broken because the "good" case (everything matches the expected pattern, 0 inverse-matches) is indistinguishable from real failure — AND grep still prints "0" to stdout first.

```bash
# WRONG — "BAD" ends up as "0\n0" when ALL lines are well-formed (the success case)
BAD=$(grep -vc '^{"ts":"' "$LOG" 2>/dev/null || echo 0)
if [ "$BAD" = "0" ]; then ...   # never true — comparison sees "0\n0"
```

Three working patterns:

```bash
# Option A — capture exit code explicitly
BAD=$(grep -vc '^{"ts":"' "$LOG" 2>/dev/null)
EXIT=$?
if [ "$EXIT" -gt 1 ]; then BAD=0; fi  # 0/1 are valid counts; 2 is real error

# Option B — collapse multi-line via head (handles the "0\n0" symptom)
BAD=$(grep -vc '^{"ts":"' "$LOG" 2>/dev/null || echo 0)
BAD=$(printf '%s\n' "$BAD" | head -1)

# Option C — sidestep grep -c entirely (RECOMMENDED)
BAD=$(grep -v '^{"ts":"' "$LOG" 2>/dev/null | wc -l | tr -d ' ')
# wc never exit-overloads; tr strips BSD wc's leading-whitespace padding
```

**Recommended:** Option C. Removes the exit-code overload entirely. `wc -l` always exits 0 and always prints one number. `tr -d ' '` handles macOS BSD wc's leading-whitespace padding (`   42` → `42`). Pattern works identically across bash 3.2/4+ and BSD/GNU coreutils.

**Where this hides:** test harnesses ("count the malformed lines"), validation scripts ("how many entries don't match the schema"), pre-commit hooks ("count secrets-like patterns"). Anywhere "the count" is the question and "0" is a possible AND meaningful answer. Caught in `~/.claude/test/bake-off/04-recorder-atomicity.sh` 2026-05-20 — the test was as specified in the plan; the recorder was always emitting well-formed JSON; the BAD check inverted the success case into a failure for the entire session of plan-writing until the implementer caught it. (workspace/feedback_grep_vc_with_default_on_error_misbehaves_at_zero.md)

## Generalization

All five patterns share a shape: **a bash construct looks intuitive but behaves differently from what reading it left-to-right suggests.** Defenses:

1. **`set -euo pipefail` is helpful but doesn't catch these.** They all produce valid bash that runs without error — just with wrong values.
2. **`set -x` debugging shows them.** When a script's behavior doesn't match the source, `set -x` (or `bash -x script.sh`) traces every expansion and reveals the mismatch.
3. **Write a quick smoke that exercises the failure path.** All four bugs above passed unit tests that mocked the inputs — they only manifested with realistic data (a non-zero exit, a multi-line value, a "0" default). Use realistic fixtures, not stub values.
4. **`shellcheck`** catches some of these (especially the `$?` reset and the bash 4+ features when shebang is `#!/usr/bin/env bash`). Run it on hooks before commit if you're not already.

## When to add a pattern to this file

These five are the validated ones. Add a sixth pattern here when:
- A bash gotcha causes a shipped bug AND
- Another data point exists (one bug = capture as feedback, two = consider adding here)

A single instance of a quirk goes to a `feedback_*` memory; a recurring pattern earns a place here.

## Cross-refs

- [[hook-design-discipline]] — broader hook engineering (block-vs-remind, stderr discipline, kill switches)
- [[mempalace-discipline]] — the file lock + retry pattern that lives in the same script family
- Source feedback files (now superseded by this synthesis):
  - `workspace/feedback_bash_dollar_question_capture_order.md`
  - `workspace/feedback_bash_var_plus_default_nonempty_gotcha.md`
  - `workspace/feedback_bash_3_2_declare_assoc_array_unsupported.md`
  - `workspace/feedback_grep_vc_with_default_on_error_misbehaves_at_zero.md`
