# Post-Install Checklist — What `install.sh` / `bootstrap.sh` Can't Script

After running `bin/install.sh` (or `bin/bootstrap.sh` on a fresh Mac), this list covers the manual setup that can't be automated — credentials, OAuth flows, API keys, and external repos.

## Must-have for the system to function

### 1. MCP server connections

The biggest remaining piece. None of the MCP server registrations are in this repo — they have per-machine credentials and OAuth flows that can't be scripted.

For each MCP server you want to use, register it:

```sh
# Via the Claude desktop app:
#   Settings → MCP Servers → Add (browser OAuth flow per server)

# Or via the CLI:
claude mcp add notion
claude mcp add gmail
claude mcp add google-calendar
# etc.
```

The original private config used these MCPs (pick what you actually need — the setup works with zero MCPs too):
- **Anthropic-managed:** Notion, Gmail, Google Calendar, Google Drive, Canva, Firecrawl, Context7 (Audible/Indeed/Miro/Mermaid/Spotify/Stripe/Vercel/Ahrefs/n8n were also in the source list)
- **Plugin-bundled:** Playwright (via `playwright` plugin), Supabase (via `supabase` plugin), Context7 (via `context7` plugin)

Each registration takes ~10–15 min including OAuth. **Plan for 30 min – 3 hours** depending on how many you wire up.

### 2. External skill repos (optional)

A few skills in the original config referenced repos that lived OUTSIDE `~/.claude/`. They're NOT included in this public snapshot but the agents reference them:

- `non-fiction-book-factory` (referenced by `content-longform` agent)
- `ebook-factory`
- `writing/`

If you want those, build them yourself or remove the references from `agents/content-longform.md`. The agents will work without them if you strip the references; they were optional in the original setup.

### 3. API keys for skills that need them

Audit each skill's `SKILL.md` for `Authenticated via X_API_KEY` lines. Known ones:

- `FIRECRAWL_API_KEY` — for the `firecrawl` skill
- Others may surface as you use more skills

Add to `~/.zshrc`:

```sh
export FIRECRAWL_API_KEY=fc-...
# etc.
```

Or to `~/.claude/settings.json` under `env: {}` if you want them only available inside Claude sessions.

### 4. gh CLI auth (prerequisite to bootstrap.sh)

Already done if you cloned the repo, but documenting:

```sh
gh auth login
# Pick GitHub.com → HTTPS → Login via web browser → paste code
```

### 5. <your-agent-project> listener install (future — Phase C of Seam 1)

When Phase C of `~/github/<your-agent-project>/HANDOFF.md` ships (the listener daemon code), it gets installed as a launchd service:

```sh
# Plan once Phase C exists:
gh repo clone <your-github-username>/<your-agent-project> ~/github/<your-agent-project>
cd ~/github/<your-agent-project>
uv sync                                    # install Python deps
sudo cp deploy/launchd/com.<your-agent-project>.runner.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.<your-agent-project>.runner.plist
```

The launchd plist needs `CLAUDE_CODE_OAUTH_TOKEN` in its env block. **Critical:** do NOT set `ANTHROPIC_API_KEY` in the same plist — Claude Code silently prefers the API key and bills at API rates ($1,800+ surprise-bill incidents in upstream issues).

## Nice-to-have

### 6. Project memory (intentionally not in this repo)

`~/.claude/projects/<project-key>/` holds per-project agent memory + conversation transcripts. NOT in this repo (privacy + size). It builds up naturally as you use Claude Code in each project.

If you're migrating from another machine and want to bring existing project memory along:

```sh
# On the source machine:
tar czf ~/Desktop/project-memory.tgz ~/.claude/projects/<your-workspace-path>

# Transfer to this machine, then:
cd ~/.claude/projects/
tar xzf ~/Desktop/project-memory.tgz
```

If you're starting fresh, skip this — memory will accumulate as you work.

### 7. Plugin install retries

`bootstrap.sh` warns on each plugin install failure but doesn't stop. Common causes:
- Marketplace not registered yet — run `claude plugin marketplace add <url>` then retry
- Plugin renamed since the manifest was captured — manually find the new name
- Plugin not available in your region or for your tier

Audit failures, fix, run plugin install loop again:

```sh
cat plugins.json | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)['plugins']))" | xargs -I {} claude plugin install {}
```

### 8. Marketplace skill conflict resolution

The repo carries snapshots of 16 marketplace skills (see `docs/install.md` step 5b). After `claude plugin install` runs in bootstrap, the marketplace versions may overwrite the snapshots OR coexist. Quick check:

```sh
# If this is a symlink, plugin install won (auto-updates work)
# If this is a directory, snapshot won (frozen but stable)
ls -la ~/.claude/skills/seo-audit
```

Both are functional. Decision is which behavior you want.

### 9. Per-machine settings.json tuning

`bootstrap.sh` wrote a generic baseline. Consider per-machine overrides:

- **Model choice** — `claude-sonnet-4-6` is the baseline. Some machines might want `claude-haiku-4-5` for cost-sensitive automation.
- **`MAX_THINKING_TOKENS`** — 63999 baseline. Lower if running on constrained memory.
- **Hook wiring** — the baseline wires CARL loader, agent-batch-validator, block-dangerous, content-qa-guarded, session-retrospective. On the Mac mini running unattended dispatched work, you may want to disable `session-retrospective` (which blocks session end on DoD checklist — pointless without an interactive user to walk it).
- **Statusline** — `gsd-statusline.js` is in `hooks/` but not wired by default in the baseline; add a `"statusLine"` config block if desired.

## Verification — Did It Work?

```sh
# 1. Skills load
claude
# In session: type /help — should list custom commands (handoff, build, ship, write, etc.)

# 2. Hooks fire
# Edit a markdown file with "I'd be happy to" — content-qa-guarded.sh should warn

# 3. CARL injects rules
# In a session: ask about Python style — should reference rules/python/style.md

# 4. Agents respond
# /plan some small feature → product-lead agent should pick it up

# 5. MCP tools available
# Try a Notion query — should work if MCP registered + auth complete

# 6. Subscription billing (not API)
# Check `claude auth status` — should show subscription, not API key
# Verify ANTHROPIC_API_KEY is unset: echo $ANTHROPIC_API_KEY (should be empty)
```

If any of these fail, see `docs/install.md` Troubleshooting section.

## Summary

**Total estimated time to full parity from a fresh Mac mini:** 4–6 hours.

| Phase | Time | Complexity |
|---|---|---|
| `bootstrap.sh` (steps 1-7) | 15 min | One copy-paste, two interactive pauses |
| MCP registration (item 1) | 2-3 hours | Per-MCP browser OAuth |
| External repo clones (item 2) | 5 min | One git command |
| API keys (item 3) | 5 min | Edit `.zshrc` |
| <your-agent-project> listener (item 5) | TBD | Doesn't exist yet |
| Verification (above) | 15 min | Walk the checklist |

Most of the 4-6 hours is MCP OAuth flows — that's unavoidable per Anthropic's auth model.
