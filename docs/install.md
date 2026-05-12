# Install Guide — Fresh Mac

End state: a Mac with the same skills, agents, commands, rules, hooks, and plugin set as the primary, authenticated against the Claude Max subscription, ready to run Claude Code interactively or headlessly.

Estimated time: ~30 min the first time, mostly waiting on plugin installs.

## Prerequisites

- macOS (the hooks assume bash + `caffeinate`; should also work on Linux with minor tweaks)
- Homebrew + git already installed
- A GitHub auth (gh CLI logged in OR HTTPS auth set up) so you can clone this repo

## 1. Install Claude Code

```sh
# Official installer — see https://docs.claude.com/en/docs/claude-code/quickstart
curl -sSL https://docs.claude.com/install.sh | bash
# Or whatever the current install path is. Check the docs first.

# Verify
claude --version
```

Required: Claude Code v2.1.91 or later if you plan to use the deep-link feature (<your-agent-project>'s Seam 2). Check current docs for newer requirements.

## 2. Clone this repo

```sh
mkdir -p ~/github
gh repo clone <your-github-username>/claude-config ~/github/claude-config
cd ~/github/claude-config
```

## 3. Run install

```sh
./bin/install.sh
```

This rsyncs `skills/`, `agents/`, `commands/`, `rules/`, `hooks/` into `~/.claude/`, plus copies `CLAUDE.md` and `settings.local.json` (the permission allowlist, no secrets).

What it does **not** do:
- It does NOT touch `~/.claude/settings.json` — that file holds machine-specific config + secrets and you populate it manually (see step 5).
- It does NOT install plugins — see step 6.
- It does NOT authenticate against Claude — see step 4.

## 4. Authenticate Claude Code

Two flavors of auth, both backed by your Claude Max subscription (no API key needed):

```sh
# A. Interactive auth (browser OAuth) — for normal Claude Code usage
claude
# This opens a browser window. Log into your Anthropic account, complete the
# OAuth grant, then exit the claude session. Subsequent invocations are
# authenticated against your subscription.

# B. Headless token (for automation, listeners, CI) — generates a 1-year token
claude setup-token
# Outputs a CLAUDE_CODE_OAUTH_TOKEN. Save it as an env var on this machine
# (e.g., add to ~/.zshrc):
#     export CLAUDE_CODE_OAUTH_TOKEN=<the-token>
# When this env var is set AND ANTHROPIC_API_KEY is unset, Claude Code uses
# the subscription. NEVER set both — Claude Code silently prefers the API
# key and bills at API rates ($1,800+ surprise bills documented in upstream
# GitHub issues).
```

## 5. Set up `~/.claude/settings.json`

`settings.json` is per-machine config. The repo doesn't carry it because it has secrets. Recommended baseline:

```json
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
```

For the full hook catalog see [docs/hooks.md](hooks.md). Wire whichever ones you want active on this machine; not every hook needs to be enabled everywhere.

## 5b. About marketplace skills

A handful of skills in `skills/` are *snapshots* of skills that originally lived as symlinks into `~/.agents/skills/` (Anthropic's official skill marketplace). Specifically: `blitzreels-carousels-tiktok`, `content-atomizer`, `content-calendar`, `content-strategy`, `copywriting`, `direct-response-copy`, `email-sequence`, `firecrawl`, `keyword-research`, `marketing-psychology`, `seo-audit`, `social-content`, `youtube-scriptwriting`.

This repo carries the snapshot. If you want them auto-updated to the latest marketplace version, install them via Claude Code's plugin manager on this machine *instead of* relying on the repo copy:

```sh
claude plugin install seo-audit
# etc. for each marketplace skill
```

Either is fine; the snapshot is just a frozen copy of what was current when `bin/sync.sh` last ran on the primary Mac.

## 6. Install plugins

The full plugin list is in `plugins.json` (144 plugins as of last sync). They span: language LSPs (typescript, pyright, gopls, etc.), code review (code-review, pr-review-toolkit, coderabbit, greptile), security (audit-context-building, differential-review, semgrep, trail-of-bits suite), framework helpers (frontend-design, ui-ux-pro-max, supabase, vercel), and meta-tooling (skill-creator, hookify, context7).

```sh
# Install one at a time (Claude Code's plugin manager doesn't have bulk install yet)
claude plugin install code-review@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
# ... etc

# OR: feed the list through xargs (be aware some plugins fail or change names)
cat ~/github/claude-config/plugins.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for name in d['plugins']:
    print(name)
" | xargs -I {} claude plugin install {}
```

You can install fewer if this is a Mac mini that only needs to run dispatched coding work — at minimum: `code-review`, `frontend-design`, `superpowers`, `pr-review-toolkit`, `compound-engineering@every-marketplace`, `everything-claude-code@everything-claude-code`.

## 7. Connect MCP servers

If you want Notion / Gmail / Calendar / Drive / etc. tools in this Claude Code instance, connect them via the Claude desktop app or via `claude mcp add <name>`. Each MCP has its own auth flow (OAuth for Notion, refresh tokens for Google, etc.) — see https://docs.claude.com/en/docs/claude-code/mcp for current docs.

For <your-agent-project>'s listener use case, MCP servers on the listener Mac are not strictly required (the dispatched `claude --print` session can use whichever MCPs are configured locally), but anything you'd use interactively, configure here too.

## 8. Verify

```sh
# Skills should be available
claude
# In the session: /help should show your custom commands
# Try: /handoff (one of the simplest commands; should produce a doc)

# Hooks should fire
# Edit any markdown file with a banned phrase like "I'd be happy to" — the
# content-qa-guarded.sh hook should warn (only on content files).

# Agents should respond
# Try: /plan some small feature — product-lead should pick it up
```

## 9. (Mac mini specific) Configure the listener

Once the dispatch listener is built (Phase 2 of ADR 0010), it goes here. Until then, this section is empty.

Future steps once it exists:
- Install the listener as a launchd service so it survives reboot
- Set `CLAUDE_CODE_OAUTH_TOKEN` in the launchd plist's environment
- Confirm Mac mini stays awake while jobs are in flight (`caffeinate -di` is invoked by the listener per-job)
- Set up a Tailscale or Cloudflare Tunnel only if you need synchronous <your-agent-project> → Mac calls; the queue + subscribe pattern doesn't need either

## Updates

When the primary Mac edits something:

```sh
# On primary Mac
cd ~/github/claude-config
./bin/sync.sh
git add -A
git commit -m "sync: <what changed>"
git push

# On any other replicated machine (Mac mini, etc.)
cd ~/github/claude-config
git pull
./bin/install.sh
```

## Troubleshooting

**`claude` command not found after install.** PATH issue. Either re-source your shell or add the install directory manually.

**Custom skills not showing up.** Verify `~/.claude/skills/<name>/SKILL.md` exists and has YAML frontmatter with `name` and `description`. Restart Claude.

**Hook not firing.** Check `~/.claude/settings.json` has the hook wired under the right lifecycle event. Hooks must be `chmod +x`. `install.sh` does this for you, but if you've added new hooks manually, run `chmod +x ~/.claude/hooks/*.sh`.

**Plugin install fails with "marketplace not found".** Some marketplaces need to be registered first. See `claude plugin marketplace add <url>` in current docs.

**Authentication keeps re-prompting.** `CLAUDE_CODE_OAUTH_TOKEN` is per-machine and expires after 1 year. Re-run `claude setup-token` to refresh.
