#!/usr/bin/env bash
# install.sh — sync this repo into ~/.claude/.
#
# ⚠️  DESTRUCTIVE: uses `rsync --delete` on ~/.claude/{skills,agents,commands,
#     rules,hooks,scripts}. Any file in those directories that is not in this
#     repo will be REMOVED. settings.json, sessions/, projects/, cache/,
#     telemetry/, and other unmanaged dirs are preserved.
#
# If you have an existing ~/.claude/ setup, back it up first:
#     cp -R ~/.claude ~/.claude.backup-$(date +%Y%m%d)
#
# Usage:
#     ./bin/install.sh           # interactive: prompts before overwriting existing setup
#     ./bin/install.sh --yes     # scripted: skip confirmation prompt
#
# Run from the repo root.

set -euo pipefail

# Arg parsing — accept --yes / -y flag and optional repo dir
YES=no
REPO_ARG=""
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=yes ;;
    *) REPO_ARG="$arg" ;;
  esac
done
REPO_DIR="${REPO_ARG:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${HOME}/.claude"

if [ ! -d "$REPO_DIR" ]; then
  echo "Error: repo dir does not exist: $REPO_DIR" >&2
  exit 1
fi
if [ ! -d "$REPO_DIR/skills" ] || [ ! -d "$REPO_DIR/agents" ]; then
  echo "Error: $REPO_DIR doesn't look like a claude-config repo (missing skills/ or agents/)" >&2
  exit 1
fi

# Warn if an existing setup will be overwritten
EXISTING=no
for d in skills agents commands rules hooks scripts; do
  if [ -d "$TARGET/$d" ] && [ "$(find "$TARGET/$d" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)" -gt 0 ]; then
    EXISTING=yes
    break
  fi
done
if [ "$EXISTING" = "yes" ]; then
  echo "⚠️  ~/.claude/ has existing content in skills/, agents/, commands/, rules/, hooks/, or scripts/."
  echo "    install.sh will rsync --delete those directories. Files not in this repo will be REMOVED."
  echo "    Other dirs (sessions/, projects/, cache/, settings.json) are preserved."
  echo ""
  if [ "$YES" = "no" ]; then
    printf "Back up first with: cp -R ~/.claude ~/.claude.backup-\$(date +%%Y%%m%%d)\n"
    printf "Continue with install? [y/N] "
    read -r confirm
    case "$confirm" in
      y|Y|yes|YES) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  else
    echo "(--yes given, proceeding)"
  fi
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

echo "→ copying CLAUDE.md → $TARGET/CLAUDE.md"
cp "$REPO_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"

# settings.local.json holds the permission allowlist (no secrets). Only install
# if the repo ships one AND the target doesn't already have one. This public
# snapshot deliberately doesn't ship settings.local.json — make your own.
if [ -f "$REPO_DIR/settings.local.json" ]; then
  if [ ! -f "$TARGET/settings.local.json" ]; then
    echo "→ copying settings.local.json → $TARGET/settings.local.json"
    cp "$REPO_DIR/settings.local.json" "$TARGET/settings.local.json"
  else
    echo "→ skipping settings.local.json (already exists; review docs/install.md to merge)"
  fi
else
  echo "→ skipping settings.local.json (not shipped in this snapshot — see docs/install.md to author your own)"
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
