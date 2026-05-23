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

# Frontmatter shape support:
#   1. Flat: all 8 v2 keys at top level (original ship-pipeline-v2 spec)
#   2. Nested: name + description at top level, the other 6 keys nested under
#      `metadata:` with 2-space indent. This is the shape MemPalace's Stop hook
#      writes for drawer-schema compatibility (it adds node_type + originSessionId).
# A key is considered present if it appears at column 0 OR indented under metadata.

# has_key <key>  →  exit 0 if key exists in either shape, else exit 1
has_key() {
  local key="$1"
  # Top-level: `key:` at column 0
  if echo "$FM" | grep -qE "^${key}:"; then
    return 0
  fi
  # Nested under metadata: indented `key:` after a `metadata:` line.
  # Awk state machine: enter "in_metadata" after seeing `^metadata:`; exit if
  # we see another column-0 key. While in_metadata, check for indented key.
  echo "$FM" | awk -v k="$key" '
    /^metadata:/ { in_meta = 1; next }
    in_meta && /^[A-Za-z]/ { in_meta = 0 }
    in_meta && $0 ~ "^[[:space:]]+"k":" { found = 1; exit }
    END { exit (found ? 0 : 1) }
  '
}

# get_key <key>  →  prints stripped value, top-level OR nested under metadata
get_key() {
  local key="$1"
  # Try top-level first
  local val
  val=$(echo "$FM" | awk -v k="$key" '
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      sub(/[[:space:]]*#.*$/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ')
  if [ -n "$val" ]; then
    echo "$val"
    return
  fi
  # Fall back to nested under metadata
  echo "$FM" | awk -v k="$key" '
    /^metadata:/ { in_meta = 1; next }
    in_meta && /^[A-Za-z]/ { in_meta = 0 }
    in_meta && $0 ~ "^[[:space:]]+"k":" {
      sub("^[[:space:]]+"k":[[:space:]]*", "")
      sub(/[[:space:]]*#.*$/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  '
}

REQUIRED_KEYS=(name description type applies-to projects severity phase last-validated)
for key in "${REQUIRED_KEYS[@]}"; do
  if ! has_key "$key"; then
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

# Detect block-list shape (forbidden — must use inline-array). Look for a line
# that is exactly `archetypes:` (no value on same line) followed by indented
# `  - ` items. Both flat and nested-under-metadata shapes.
if echo "$FM" | grep -qE '^(  )?archetypes:[[:space:]]*$'; then
  echo "ERROR: 'archetypes' field in $FILE uses block-list YAML syntax; must use inline-array (e.g., archetypes: [web-app, telegram-bot])" >&2
  exit 1
fi

# Optional: archetypes field. If present, every value must be in the known vocabulary.
ARCHETYPES_RAW=$(get_key archetypes)
if [ -n "$ARCHETYPES_RAW" ]; then
  ARCH_LIST=$(echo "$ARCHETYPES_RAW" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  while IFS= read -r arch; do
    [ -z "$arch" ] && continue
    case "$arch" in
      web-app|telegram-bot|content-pipeline|python-cli|video-pipeline|infra-config|brand-content|always-on) ;;
      *) echo "ERROR: invalid archetype '$arch' in $FILE (must be: web-app|telegram-bot|content-pipeline|python-cli|video-pipeline|infra-config|brand-content|always-on)" >&2; exit 1 ;;
    esac
  done <<< "$ARCH_LIST"
fi

echo "OK: $FILE"
