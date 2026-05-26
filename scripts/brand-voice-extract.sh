#!/usr/bin/env bash
# brand-voice-extract.sh — extract the shared preamble + one brand section
# from brand-voice-router/SKILL.md. Returns ~40-60% of the full file.
#
# Usage: brand-voice-extract.sh <brand>
#   brand: outline | unstuck | diversified | <your-direct-lane> | all (full file)
#
# The preamble (always included): What This Skill Does, Voice Source of Truth,
# THE CENTRAL PATTERN, Register Awareness, Brand Detection, Application Rules,
# Integration with Other Skills. These are shared rules that apply regardless
# of which brand is active.
#
# Output: the combined markdown on stdout.
# Exit: 0 on success, 1 on bad args, 2 if SKILL.md not found.

set -euo pipefail

SKILL_FILE="${BRAND_VOICE_SKILL:-$HOME/.claude/skills/brand-voice-router/SKILL.md}"

if [ ! -f "$SKILL_FILE" ]; then
  echo "brand-voice-extract: SKILL.md not found at $SKILL_FILE" >&2
  exit 2
fi

BRAND="${1:-}"

if [ -z "$BRAND" ]; then
  echo "Usage: brand-voice-extract.sh <outline|unstuck|diversified|<your-direct-lane>|all>" >&2
  exit 1
fi

# Full file shortcut
if [ "$BRAND" = "all" ]; then
  cat "$SKILL_FILE"
  exit 0
fi

# Map brand arg → H2 heading pattern
case "$BRAND" in
  outline)        PATTERN="Brand 1: <your third brand>" ;;
  unstuck)        PATTERN="Brand 2: <your brand>" ;;
  diversified)    PATTERN="Brand 3: <your second brand>" ;;
  <your-direct-lane>)   PATTERN="Brand 4: you Direct" ;;
  *)
    echo "brand-voice-extract: unknown brand '$BRAND'. Use: outline|unstuck|diversified|<your-direct-lane>|all" >&2
    exit 1
    ;;
esac

# Extract sections using awk:
# - Preamble = everything from start until the first "## Brand N:" heading
# - Brand section = from "## Brand N: ..." until the next "## Brand" or "## Application"
# - Footer = "## Application Rules" through end of file
awk -v pat="$PATTERN" '
  BEGIN { mode="preamble"; found=0 }
  /^## Brand [0-9]+:/ {
    if (index($0, pat) > 0) {
      mode="brand"; found=1; print; next
    } else if (mode == "preamble") {
      mode="skip"; next
    } else if (mode == "brand") {
      mode="skip"; next
    } else {
      next
    }
  }
  /^## Application Rules/ { mode="footer" }
  mode == "preamble" { print; next }
  mode == "brand"    { print; next }
  mode == "footer"   { print; next }
' "$SKILL_FILE"
