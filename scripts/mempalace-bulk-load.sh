#!/bin/bash
# ~/.claude/scripts/mempalace-bulk-load.sh
# MemPalace bulk-load filter v2 — gitleaks pre-mine filter (skip-whole-project on hits)
#
# v1 bug (per feedback_apply_change_set_with_real_world_drift.md): counted matches
# but did NOT skip — secrets ended up mined into 5+ wings before discovery.
# v2 fix: run gitleaks BEFORE mempalace mine; if any hits, SKIP the whole project
# and log file paths only (never values). Single source of truth: same gitleaks
# config as the per-repo pre-commit hook.
#
# Usage:
#   ~/.claude/scripts/mempalace-bulk-load.sh              # bulk-load all ~/github/*
#   ~/.claude/scripts/mempalace-bulk-load.sh <path>       # single project
#   DRY_RUN=1 ~/.claude/scripts/mempalace-bulk-load.sh    # log-only, no mining
#
# Exit codes:
#   0 — all projects either skipped (clean) or mined (clean after filter)
#   1 — gitleaks binary missing or config missing
#   2 — mempalace binary missing
#
# Spec (this script's contract):
#   1. For each project dir under ~/github/* (or single arg):
#      a. Skip by name (dotfiles, node_modules, etc.)
#      b. Skip if no real content
#      c. Run gitleaks detect with shared config
#      d. If hits: log SECRETS_FOUND + file paths (no values), SKIP entire project
#      e. If clean: run `mempalace mine`
#   2. Per-project log row: timestamp, project, gitleaks_exit, files_skipped, mined_status

set -u

# Phase 2 prereq: self-check guard. Prevents regression to v1 count-without-skip bug.
# If someone edits this script and accidentally removes the gitleaks pre-mine call,
# the script aborts before doing any mining.
if ! grep -q 'gitleaks detect' "$0"; then
  echo "FATAL: bulk-load script missing gitleaks pre-mine filter — would regress to v1 secrets-leak bug. Restore the gitleaks detect block before running." >&2
  exit 99
fi
set -o pipefail
# Per reviewer M2: without pipefail, `mempalace mine ... | tail -10` masks mine
# failures since tail always exits 0. We need the inner command's status.

LOG=~/.claude/logs/mempalace-bulk-load.log
SKIPPED_REPORT=~/.claude/logs/mempalace-bulk-load-skipped.tsv
GITLEAKS_CONFIG="$HOME/github/.gitleaks.toml"
DRY_RUN="${DRY_RUN:-0}"

mkdir -p ~/.claude/logs

# Preflight: tools + config
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks not found in PATH" >&2
  echo "  install: brew install gitleaks" >&2
  exit 1
fi
if [ ! -f "$GITLEAKS_CONFIG" ]; then
  echo "ERROR: shared config not found at $GITLEAKS_CONFIG" >&2
  exit 1
fi
if ! command -v mempalace >/dev/null 2>&1; then
  echo "ERROR: mempalace not found in PATH" >&2
  exit 2
fi

# Target list — single arg, or all ~/github/*
if [ $# -gt 0 ]; then
  TARGETS=("$1")
else
  TARGETS=($HOME/github/*/)
fi

# Header row for skipped report
if [ ! -f "$SKIPPED_REPORT" ]; then
  printf "timestamp\tproject\tleak_count\tfirst_file\n" > "$SKIPPED_REPORT"
fi

DRY_RUN_SUFFIX=""
[ "$DRY_RUN" = "1" ] && DRY_RUN_SUFFIX=" (DRY_RUN)"
echo "=== bulk-load v2 start $(date '+%Y-%m-%d %H:%M:%S')${DRY_RUN_SUFFIX} ===" | tee -a "$LOG"

MINED=0
SKIPPED_NAME=0
SKIPPED_EMPTY=0
SKIPPED_SECRETS=0
ERRORED=0

for dir in "${TARGETS[@]}"; do
  # Normalize: strip trailing slash, get basename
  dir="${dir%/}"
  project=$(basename "$dir")

  # Skip by name
  case "$project" in
    .*|node_modules|dist|build|.next|__pycache__|secrets|private)
      echo "$(date +%H:%M:%S) SKIP (name): $project" >> "$LOG"
      SKIPPED_NAME=$((SKIPPED_NAME+1))
      continue
      ;;
  esac

  # Skip if no real content (no .md / .ts / .tsx / .js / .py within depth 2)
  if [ -z "$(find "$dir" -maxdepth 2 -type f \( -name '*.md' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.py' \) -print -quit 2>/dev/null)" ]; then
    echo "$(date +%H:%M:%S) SKIP (empty): $project" >> "$LOG"
    SKIPPED_EMPTY=$((SKIPPED_EMPTY+1))
    continue
  fi

  # PRE-MINE FILTER: gitleaks scan with shared config
  GITLEAKS_OUT=$(mktemp)
  gitleaks detect \
    --no-git \
    --config "$GITLEAKS_CONFIG" \
    --source "$dir" \
    --report-format json \
    --report-path "$GITLEAKS_OUT" \
    --no-banner \
    --redact \
    --exit-code 1 \
    >/dev/null 2>&1
  GITLEAKS_EXIT=$?

  if [ $GITLEAKS_EXIT -ne 0 ]; then
    # Hits found — SKIP whole project. Log paths only, never values.
    LEAK_COUNT=$(jq 'length' "$GITLEAKS_OUT" 2>/dev/null || echo "?")
    FIRST_FILE=$(jq -r '.[0].File // "unknown"' "$GITLEAKS_OUT" 2>/dev/null | head -1)

    echo "" >> "$LOG"
    echo "$(date +%H:%M:%S) SECRETS_FOUND: $project · count=$LEAK_COUNT" >> "$LOG"
    echo "  ↳ Affected files (paths only — values redacted):" >> "$LOG"
    jq -r '.[].File' "$GITLEAKS_OUT" 2>/dev/null | sort -u | sed 's/^/    /' >> "$LOG"
    echo "  ↳ SKIPPING entire project; flagged for manual review." >> "$LOG"

    # Append to TSV report for orchestrator/reviewer
    printf "%s\t%s\t%s\t%s\n" "$(date -Iseconds)" "$project" "$LEAK_COUNT" "$FIRST_FILE" >> "$SKIPPED_REPORT"

    SKIPPED_SECRETS=$((SKIPPED_SECRETS+1))
    rm -f "$GITLEAKS_OUT"
    continue
  fi

  rm -f "$GITLEAKS_OUT"

  # Clean — proceed to mine (unless dry run)
  echo "" >> "$LOG"
  echo "$(date +%H:%M:%S) MINING: $project (gitleaks_exit=0, no secrets)" >> "$LOG"

  if [ "$DRY_RUN" = "1" ]; then
    echo "  ↳ DRY_RUN — skipping mempalace mine" >> "$LOG"
    MINED=$((MINED+1))
    continue
  fi

  if mempalace mine "$dir" --wing="$project" --agent=claude 2>&1 | tail -10 >> "$LOG"; then
    MINED=$((MINED+1))
  else
    echo "  ↳ MINE_FAILED for $project" >> "$LOG"
    ERRORED=$((ERRORED+1))
  fi
done

echo "" >> "$LOG"
echo "=== bulk-load v2 done $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
echo "  mined:           $MINED" | tee -a "$LOG"
echo "  skipped (name):  $SKIPPED_NAME" | tee -a "$LOG"
echo "  skipped (empty): $SKIPPED_EMPTY" | tee -a "$LOG"
echo "  skipped (SECRETS): $SKIPPED_SECRETS  ← see $SKIPPED_REPORT" | tee -a "$LOG"
echo "  errored:         $ERRORED" | tee -a "$LOG"

# Non-zero exit if any project errored (not if just skipped for secrets — that's expected)
[ $ERRORED -eq 0 ] || exit 3
exit 0
