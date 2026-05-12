#!/usr/bin/env bash
# sync.sh — pull current state of ~/.claude/ INTO this repo.
#
# Inverse of install.sh. Run on the primary Mac after editing skills/agents/
# commands/rules/hooks live in ~/.claude/, to capture the changes back into
# the repo before commit + push.
#
# Usage: ./bin/sync.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${HOME}/.claude"

if [ ! -d "$SOURCE" ]; then
  echo "Error: $SOURCE does not exist" >&2
  exit 1
fi

# skills/ uses -L (follow symlinks) because some skills are symlinks into
# ~/.agents/skills/ (Anthropic's marketplace skill directory). We capture
# them as snapshots in the repo. Caveat: marketplace updates won't propagate
# automatically to replicated machines — install marketplace skills via
# `claude plugin install` on each machine if you want auto-updates.
echo "→ syncing $SOURCE/skills/ → repo/skills/ (following symlinks)"
rsync -aL --delete --exclude='.DS_Store' --exclude='.git' "$SOURCE/skills/" "$REPO_DIR/skills/"

echo "→ syncing $SOURCE/agents/ → repo/agents/"
rsync -a --delete --exclude='.DS_Store' "$SOURCE/agents/" "$REPO_DIR/agents/"

echo "→ syncing $SOURCE/commands/ → repo/commands/ (following symlinks)"
rsync -aL --delete --exclude='.DS_Store' "$SOURCE/commands/" "$REPO_DIR/commands/"

echo "→ syncing $SOURCE/rules/ → repo/rules/"
rsync -a --delete --exclude='.DS_Store' "$SOURCE/rules/" "$REPO_DIR/rules/"

echo "→ syncing $SOURCE/hooks/ → repo/hooks/"
rsync -a --delete --exclude='.DS_Store' "$SOURCE/hooks/" "$REPO_DIR/hooks/"

if [ -d "$SOURCE/scripts" ]; then
  echo "→ syncing $SOURCE/scripts/ → repo/scripts/"
  rsync -a --delete --exclude='.DS_Store' "$SOURCE/scripts/" "$REPO_DIR/scripts/"
fi

echo "→ copying CLAUDE.md → repo/CLAUDE.md"
cp "$SOURCE/CLAUDE.md" "$REPO_DIR/CLAUDE.md"

# settings.local.json: copy if it exists (it's the no-secret allowlist).
if [ -f "$SOURCE/settings.local.json" ]; then
  echo "→ copying settings.local.json → repo/settings.local.json"
  cp "$SOURCE/settings.local.json" "$REPO_DIR/settings.local.json"
fi

# Re-sanitize absolute paths in hooks (in case you added new ones with
# $HOME embedded). Replaces with $HOME so they're portable.
echo "→ sanitizing absolute paths in hooks/"
find "$REPO_DIR/hooks" -type f \( -name '*.sh' -o -name '*.js' \) | while read -r f; do
  if grep -q '$HOME' "$f"; then
    sed -i.bak 's|$HOME|$HOME|g' "$f"
    rm "$f.bak"
    echo "  - sanitized: $(basename "$f")"
  fi
done

echo
echo "✓ sync complete. Review with \`git diff\` then commit + push."
