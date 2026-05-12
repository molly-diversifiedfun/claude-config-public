#!/usr/bin/env bash
# bootstrap.sh — one-shot setup for a fresh Mac.
#
# Run from the cloned repo dir. Does as much as possible automatically;
# pauses ONCE for the Claude Code OAuth login (which must be interactive).
#
# Usage:
#   git clone <repo>
#   cd claude-config
#   bin/bootstrap.sh
#
# What it does, in order:
#   1. Verifies prerequisites (git, curl, gh CLI, Homebrew)
#   2. Installs Claude Code if not present
#   3. Runs bin/install.sh (rsyncs skills/agents/commands/rules/hooks/scripts → ~/.claude/)
#   4. Writes a baseline ~/.claude/settings.json (skipping if one exists)
#   5. Prompts user to run `claude` once for browser OAuth (interactive)
#   6. Prompts user to run `claude setup-token` for headless OAuth token
#   7. Bulk-installs all plugins from plugins.json
#   8. Done — prints next steps
#
# Estimated runtime: 5-15 min (mostly waiting on plugin installs).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SETTINGS_PATH="${CLAUDE_DIR}/settings.json"

heading() { printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
ok()      { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn()    { printf "  \033[33m⚠\033[0m %s\n" "$*"; }
fail()    { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. prereqs

heading "Step 1/8 — Verifying prerequisites"

command -v git >/dev/null  || fail "git not found. Install Xcode CLI tools: xcode-select --install"
command -v curl >/dev/null || fail "curl not found"
command -v gh >/dev/null   || warn "gh CLI not found — needed for repo clone but not for this script. Install: brew install gh"
command -v rsync >/dev/null || fail "rsync not found (should be system default)"
ok "git, curl, rsync present"

# ---------------------------------------------------------------- 2. claude

heading "Step 2/8 — Installing Claude Code (skipping if already present)"

if command -v claude >/dev/null; then
  CC_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
  ok "Claude Code already installed: $CC_VERSION"
else
  warn "Claude Code not found — installing"
  # Anthropic's install path may change; check current docs if this fails
  curl -sSL https://docs.claude.com/install.sh | bash || fail "Claude Code install failed"
  ok "Claude Code installed"
fi

# ---------------------------------------------------------------- 3. install.sh

heading "Step 3/8 — Running install.sh (rsync repo → ~/.claude/)"
"$REPO_DIR/bin/install.sh"

# ---------------------------------------------------------------- 4. settings.json

heading "Step 4/8 — Writing baseline ~/.claude/settings.json"

if [ -f "$SETTINGS_PATH" ]; then
  ok "settings.json already exists at $SETTINGS_PATH — leaving alone"
else
  cat > "$SETTINGS_PATH" <<'JSON'
{
  "model": "claude-sonnet-4-6",
  "alwaysThinkingEnabled": true,
  "env": {
    "MAX_THINKING_TOKENS": "63999"
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/carl-loader.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/agent-batch-validator.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/block-dangerous.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/content-qa-guarded.sh" }
        ]
      },
      {
        "matcher": "Agent|Bash",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/ship-phase-gate.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/session-retrospective.sh" }
        ]
      }
    ]
  }
}
JSON
  ok "Wrote baseline settings.json"
fi

# ---------------------------------------------------------------- 5. claude login

heading "Step 5/8 — Authenticate Claude Code (browser OAuth, interactive)"

cat <<EOF
   Claude Code needs a one-time browser OAuth grant against your
   Anthropic account. This pairs the CLI with your Claude Max
   subscription so requests bill against the subscription, not API.

   In another terminal, run:
       claude

   Complete the browser flow, then exit (Ctrl+D or /quit).
   When done, press ENTER here to continue.
EOF
read -r -p "  Press ENTER after \`claude\` login complete..." _

# ---------------------------------------------------------------- 6. setup-token

heading "Step 6/8 — Generate headless OAuth token (for listener / automation)"

cat <<EOF
   For headless / non-interactive use (the <your-agent-project> listener daemon
   will need this), generate a 1-year OAuth token:

       claude setup-token

   This prints a token like \`ant-cct-...\`. Copy it and add to your
   shell profile (~/.zshrc):

       export CLAUDE_CODE_OAUTH_TOKEN=ant-cct-...

   IMPORTANT: do NOT also set ANTHROPIC_API_KEY in the same shell —
   Claude Code silently prefers the API key and bills at API rates.

   When done, press ENTER here.
EOF
read -r -p "  Press ENTER after \`claude setup-token\` complete (or skip if not needed)..." _

# ---------------------------------------------------------------- 7. plugins

heading "Step 7/8 — Installing plugins from plugins.json"

if [ ! -f "$REPO_DIR/plugins.json" ]; then
  warn "plugins.json not found in repo, skipping plugin install"
else
  PLUGIN_COUNT=$(python3 -c "import json; print(len(json.load(open('$REPO_DIR/plugins.json'))['plugins']))")
  echo "  $PLUGIN_COUNT plugins to install. This will take a while."
  read -r -p "  Install all $PLUGIN_COUNT plugins now? [y/N] " yn
  case "$yn" in
    [yY]*)
      python3 -c "
import json
for p in json.load(open('$REPO_DIR/plugins.json'))['plugins']:
    print(p)
" | while read -r plugin; do
        echo "  → installing $plugin"
        claude plugin install "$plugin" 2>/dev/null || warn "failed: $plugin (may already be installed or marketplace not registered)"
      done
      ok "Plugin install loop complete (some may have failed; review output)"
      ;;
    *)
      warn "Skipping plugin install. Run later with:"
      echo "    cat plugins.json | python3 -c \"import json,sys; print('\\n'.join(json.load(sys.stdin)['plugins']))\" | xargs -I {} claude plugin install {}"
      ;;
  esac
fi

# ---------------------------------------------------------------- 8. done

heading "Step 8/8 — Done"

cat <<EOF

  ✓ Bootstrap complete.

  What's set up:
    - Claude Code installed + authenticated
    - ~/.claude/{skills,agents,commands,rules,hooks} populated from this repo
    - ~/.claude/CLAUDE.md global instructions in place
    - Baseline ~/.claude/settings.json (review + customize as needed)
    - Plugins installing (if you said yes above)

  What's NOT yet set up (manual / future-Claude):
    - MCP servers (Notion, Gmail, Calendar, etc.) — add via the Claude
      desktop app or \`claude mcp add\` per-MCP, each has its own auth
    - <your-agent-project> listener daemon (Phase B/C of Seam 1, doesn't exist yet)
    - Any per-machine tweaks (statusline, theme, etc.)

  Next:
    - Try \`claude\` to open a session and verify your skills/agents load
    - For <your-agent-project> listener install: see ~/github/<your-agent-project>/HANDOFF.md
      under "Phase B" once that work begins

  To pull updates from the primary Mac later:
    cd $REPO_DIR
    git pull
    bin/install.sh
EOF
