#!/usr/bin/env bash
# validate-frontmatter.sh — checks a markdown file has the v2 ship-pipeline frontmatter.
# See spec: docs/superpowers/specs/2026-05-10-ship-pipeline-v2-design.md
# Usage: validate-frontmatter.sh <file.md>
# Exit 0 = valid. Exit 1 = invalid (prints reason to stderr).

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <markdown-file>" >&2
  echo "Validates v2 ship-pipeline frontmatter (8 required keys + type + severity vocabularies)." >&2
  exit 1
}

[ $# -eq 1 ] || usage
case "$1" in -h|--help) usage ;; esac

FILE="$1"
[ -f "$FILE" ] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }

# Single awk pass: extract frontmatter between two fence lines, tolerating
# CRLF and trailing whitespace. Emits "key: value" lines (one per top-level
# key) on stdout. Exits 2 if no opening fence, 3 if no closing fence.
FM=$(awk '
  BEGIN { state = 0 }
  # Opening fence: literally three dashes optionally followed by whitespace/CR
  /^---[[:space:]]*\r?$/ {
    if (state == 0) { state = 1; next }
    if (state == 1) { state = 2; exit }
  }
  state == 1 {
    sub(/\r$/, "")
    print
  }
  END {
    if (state == 0) exit 2
    if (state == 1) exit 3
  }
' "$FILE") || {
  rc=$?
  case "$rc" in
    2) echo "ERROR: no frontmatter block in $FILE" >&2; exit 1 ;;
    3) echo "ERROR: unclosed frontmatter (missing closing --- fence) in $FILE" >&2; exit 1 ;;
    *) echo "ERROR: failed to parse frontmatter in $FILE (awk rc=$rc)" >&2; exit 1 ;;
  esac
}

# get_key <key>  →  prints stripped value of top-level frontmatter key, or empty
get_key() {
  local key="$1"
  # Match "key:" anchored at column 0, take everything after the first colon,
  # strip inline `# comment`, strip leading/trailing whitespace.
  echo "$FM" | awk -v k="$key" '
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      sub(/[[:space:]]*#.*$/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  '
}

REQUIRED_KEYS=(name description type applies-to projects severity phase last-validated)
for key in "${REQUIRED_KEYS[@]}"; do
  if ! echo "$FM" | grep -qE "^${key}:"; then
    echo "ERROR: missing key '$key' in $FILE" >&2
    exit 1
  fi
done

TYPE=$(get_key type)
case "$TYPE" in
  learned-pattern|feedback|project|reference|user) ;;
  "") echo "ERROR: empty value for 'type' in $FILE" >&2; exit 1 ;;
  *) echo "ERROR: invalid type '$TYPE' in $FILE (must be: learned-pattern|feedback|project|reference|user)" >&2; exit 1 ;;
esac

SEV=$(get_key severity)
case "$SEV" in
  blocking|warning|info) ;;
  "") echo "ERROR: empty value for 'severity' in $FILE" >&2; exit 1 ;;
  *) echo "ERROR: invalid severity '$SEV' in $FILE (must be: blocking|warning|info)" >&2; exit 1 ;;
esac

echo "OK: $FILE"
