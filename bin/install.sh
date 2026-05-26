#!/usr/bin/env bash
# install.sh — copy the contents of this repo into ~/.claude/.
#
# Idempotent: re-running overwrites whatever's in ~/.claude/{skills,agents,commands,rules,hooks},
# preserving anything else (settings.json with secrets, sessions/, projects/, cache/, etc.).
#
# Usage: ./bin/install.sh
#
# Run from the repo root or with the repo dir as argv[1].

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${HOME}/.claude"

if [ ! -d "$REPO_DIR" ]; then
  echo "Error: repo dir does not exist: $REPO_DIR" >&2
  exit 1
fi
if [ ! -d "$REPO_DIR/skills" ] || [ ! -d "$REPO_DIR/agents" ]; then
  echo "Error: $REPO_DIR doesn't look like a claude-config repo (missing skills/ or agents/)" >&2
  exit 1
fi

mkdir -p "$TARGET"

echo "→ syncing skills/ → $TARGET/skills/"
rsync -a --delete --exclude='.DS_Store' "$REPO_DIR/skills/" "$TARGET/skills/"

echo "→ syncing agents/ → $TARGET/agents/"
rsync -a --delete --exclude='.DS_Store' "$REPO_DIR/agents/" "$TARGET/agents/"

echo "→ syncing commands/ → $TARGET/commands/"
rsync -a --delete --exclude='.DS_Store' "$REPO_DIR/commands/" "$TARGET/commands/"

echo "→ syncing rules/ → $TARGET/rules/"
rsync -a --delete --exclude='.DS_Store' "$REPO_DIR/rules/" "$TARGET/rules/"

echo "→ syncing hooks/ → $TARGET/hooks/"
rsync -a --delete --exclude='.DS_Store' "$REPO_DIR/hooks/" "$TARGET/hooks/"
chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true

if [ -d "$REPO_DIR/scripts" ]; then
  echo "→ syncing scripts/ → $TARGET/scripts/"
  rsync -a --delete --exclude='.DS_Store' "$REPO_DIR/scripts/" "$TARGET/scripts/"
  chmod +x "$TARGET/scripts/"*.sh 2>/dev/null || true
  chmod +x "$TARGET/scripts/"*.py 2>/dev/null || true
fi

# CARL lives at ~/.carl/, not ~/.claude/. Install the domain files if the
# repo has them. NOT a --delete sync: a live carl/n8n file (gitignored,
# contains infra references; created manually per CHECKLIST.md item 2b)
# must survive re-runs of install.sh.
if [ -d "$REPO_DIR/carl" ]; then
  echo "→ syncing carl/ → $HOME/.carl/  (no --delete; preserves local carl/n8n)"
  mkdir -p "$HOME/.carl"
  rsync -a --exclude='.DS_Store' --exclude='n8n' "$REPO_DIR/carl/" "$HOME/.carl/"
fi

# Root-level YAML configs (Phase 7.1 archetype injection).
for yaml in projects.yaml skill-archetypes.yaml work-type-chains.yaml; do
  if [ -f "$REPO_DIR/$yaml" ]; then
    echo "→ copying $yaml → $TARGET/$yaml"
    cp "$REPO_DIR/$yaml" "$TARGET/$yaml"
  fi
done

echo "→ copying CLAUDE.md → $TARGET/CLAUDE.md"
cp "$REPO_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"

# settings.local.json holds the permission allowlist (no secrets). Only install
# if there isn't one already — don't clobber a user's local tweaks.
if [ ! -f "$TARGET/settings.local.json" ]; then
  echo "→ copying settings.local.json → $TARGET/settings.local.json"
  cp "$REPO_DIR/settings.local.json" "$TARGET/settings.local.json"
else
  echo "→ skipping settings.local.json (already exists; review docs/install.md to merge)"
fi

# settings.json is NEVER copied — it has machine-specific config + secrets.
if [ ! -f "$TARGET/settings.json" ]; then
  cat <<EOF
⚠ $TARGET/settings.json does not exist on this machine.
   See docs/install.md for the recommended baseline (model, env vars, hooks
   wiring). You'll want to fill in API keys / Anthropic OAuth token here.
EOF
fi

echo
echo "✓ install complete."
echo
echo "Next steps:"
echo "  1. Authenticate Claude Code: \`claude\` (one-time browser login)"
echo "  2. For headless use: \`claude setup-token\` → CLAUDE_CODE_OAUTH_TOKEN"
echo "  3. Install plugins (see docs/install.md for the list)"
echo "  4. Review $TARGET/CLAUDE.md for any per-machine tweaks needed"
