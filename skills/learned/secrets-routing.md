---
name: secrets-routing
description: Secrets go DIRECT to deploy target (Railway/Vercel/1Password). Never paste keys to chat. Avoid Railway Raw Editor — leaks all values.
type: learned-pattern
applies-to: [secrets, deploy, infra]
projects: [all]
severity: blocking
phase: [build, deploy]
trigger: [api-key, oauth-secret, env-var-add, raw-editor]
last-validated: 2026-05-19
archetypes: [always-on]
---

# Pattern: Secrets Go Direct to Deploy Target

API keys, bot tokens, OAuth secrets, service role keys, refresh tokens — never travel through chat. Default workflow: you sets them directly in the deploy target (Railway/Vercel env, 1Password) and tells Claude "set."

## Why workflow, not warnings

By the time Claude warns, the secret is already in conversation logs and must be rotated. you optimizes for "fast handoff to Claude" over secret hygiene. The fix is workflow design.

<your-personal-ai-project> kickoff (2026-05-05): she pasted Anthropic API key + fresh Telegram bot token directly into chat for speed despite explicit warnings each time.

## Pre-instruct before secret-producing actions

When listing required inputs at session start, mark secrets explicitly:
> "Set `FOO_KEY` directly in Railway env and tell me 'set'"
NOT:
> "Paste FOO_KEY here."

For flows that naturally produce a secret, pre-instruct *before she does the action*:
- BotFather `/newbot` → "BotFather will show a token after `/newbot` — copy that one straight into Railway, don't paste it here, then come back and say 'set'."
- Stripe dashboard → similar, route directly to env or 1Password
- Supabase service role reveal → similar

## If she pastes anyway

- Never echo it back
- Instruct rotation
- Update inputs file with "rotation pending" only

## Browser automation that touches credentials

Playwright/browser snapshots land in tool outputs which land in conversation logs (same failure mode). Refuse and explain. Recommend manual + password manager.

## Railway Raw Editor leaks all secrets

Confirmed 2026-05-07 on the <your-personal-ai-project> service. Opening Railway's **Raw Editor** for service variables loads every existing secret as plaintext in the page DOM. The CodeMirror block's `[contenteditable] [role=textbox]` element contains the *full set of existing service env vars* unredacted. Reading any DOM property — `textContent`, `innerText`, `value` — pulls them all into conversation context.

**Fix:** for adding a single new env var via Playwright, use the **"New Variable"** button — only that one row's editor fields are interactive.

For bulk edits where you need to see existing values, accept the leak but **rotate every exposed secret afterwards.** Treat Raw Editor as a destructive action for any secrets it surfaces.

Same caution applies to any platform's "raw env editor" surface (Vercel, Fly.io likely have similar). Verify on first use whether existing values are shown plaintext or masked.

## Refresh tokens have lifecycles too

<your-agent-project>'s Google OAuth refresh token expires every 7 days while the OAuth app is in Testing mode. Re-run `setup_gmail_oauth.py` weekly. To make permanent, the app needs Google verification. Schedule a watchdog before the expiry window or it dies silently.

## Post-rotation gitleaks audit: categorize before reacting (NEW 2026-05-19)

After a rotation, a `gitleaks detect --no-git --source <workspace>` will return many hits that are NOT actual leaks. Bucket them first; the runbook's "verification: no findings" check is the END state, not the precondition for the history scrub. Observed 2026-05-19 night: post-rotation scan returned 420 hits across 19 dirs. After categorization, **0 were real**. Categories where gitleaks is wrong by default:

| Bucket | Why gitleaks flagged it | Treat as |
|---|---|---|
| Newly-populated `.env` (gitignored) | Working-tree scan sees ALL files regardless of git status | **Expected.** Allowlist `.env` / `.env.local` in `~/github/.gitleaks.toml` paths — pre-commit hook uses `protect --staged` which never sees gitignored files anyway. |
| `.playwright-mcp/page-*.yml` captures | Browser DOM snapshots preserved tokens in headers / form inputs | **Artifact.** Delete + gitignore the dir. |
| Test smoke / redaction-test fixtures | Tests need key-shaped strings to verify redaction works | **False positive.** Allowlist the synthetic patterns (`sk-ant-api03-a{10,}...`, JWT.io standard example, etc.) — NOT the test path (path-allowlist masks future real-token regressions). |
| `.claude/settings.local.json` | Tokens captured from prompts/env | **Sanitize + allowlist** — always gitignored, never commits. |
| Conversation-export JSON dumps | Tokens quoted in past LLM conversations | **Delete** if disposable; allowlist `conversation-knowledge-extractor/data-*` if kept. |
| Documentation mentioning key SHAPES | Docs like "Anthropic keys look like sk-ant-api03-..." | **Path allowlist** `docs/*.md` + `SKILL.md` + `install.sh`. |
| n8n workflow JSON exports | `"keyValue":"<uuid>"` config refs trip generic-api-key | **UUID regex allowlist** + path allowlist for `n8n-workflows/*.json`. |
| PostHog `phc_*` keys | Public by design (embedded in client bundles, RLS-gated) | **Regex allowlist** per PostHog docs. |
| Canary tokens like `SPS-CANARY-YYYY-MM-DD-HEX` | Intentional detectable strings for prompt-injection testing | **Regex allowlist** for the canary shape. |

Canonical allowlist seed for any new repo: `feedback_gitleaks_allowlist_classes_to_codify.md`. Net result on 2026-05-19: 420 → 0 hits after applying the path + regex allowlists. (workspace/feedback_gitleaks_audit_categorization.md, feedback_gitleaks_allowlist_classes_to_codify.md)

## `.mcp.json` is a secrets file too (NEW 2026-05-19)

Hidden secrets class: `~/github/<project>/.mcp.json` for local Claude Code MCP server configs often contains `--access-token`, Bearer tokens, etc. — these are REAL credentials for management-plane APIs (Supabase `sbp_*`, Buffer Bearer, Sentry tokens). They're properly gitignored by default but may show up in `git log` history if committed earlier. Add `sbp_[a-f0-9]{40,}` and similar management-plane shapes to gitleaks rules as a CRITICAL severity. (workspace/feedback_gitleaks_allowlist_classes_to_codify.md addendum, secrets-rotation.md table rows 7-8)

## Cross-refs

- `git-history-scrub-discipline.md` — for the destructive history-rewrite operation (filter-repo gotchas)
- `deploy-iteration-discipline.md` — change-set drift; secrets are shared-state, irreversible-on-leak
- `~/github/<your-agent-project>/.claude/rules/rejected-patterns.md` — "Don't ask the user to paste API keys"
- `~/github/docs/conventions/secrets-rotation.md` — rotation runbook (Anthropic, Supabase service-role + management, Telegram bots, Apify, Buffer, Gumroad)
- `~/github/.gitleaks.toml` — shared config seeded with the 7 path classes + 8 regex patterns above
- Workspace memory: `feedback_secrets_go_direct_to_deploy.md`, `feedback_railway_raw_editor_leaks_secrets.md`, `feedback_gitleaks_audit_categorization.md`, `feedback_gitleaks_allowlist_classes_to_codify.md`, `reference_cloud_secret_show_once.md`
