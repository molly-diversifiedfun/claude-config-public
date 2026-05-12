---
name: secrets-routing
description: Secrets go DIRECT to deploy target (Railway/Vercel/1Password). Never paste keys to chat. Avoid Railway Raw Editor — leaks all values.
type: learned-pattern
applies-to: [secrets, deploy, infra]
projects: [all]
severity: blocking
phase: [build, deploy]
trigger: [api-key, oauth-secret, env-var-add, raw-editor]
last-validated: 2026-05-07
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

## Cross-refs

- `deploy-iteration-discipline.md` — change-set drift; secrets are shared-state, irreversible-on-leak
- `~/github/<your-agent-project>/.claude/rules/rejected-patterns.md` — "Don't ask the user to paste API keys"
- Workspace memory: `feedback_secrets_go_direct_to_deploy.md`, `feedback_railway_raw_editor_leaks_secrets.md`, `reference_cloud_secret_show_once.md`
