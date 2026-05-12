---
name: n8n-production-patterns
description: Hard-won n8n + Postgres + Apify + Meta API constraints from the content-system signal pipeline. Patterns aren't documented in n8n's UI — each swallowed a session before being captured.
type: learned-pattern
applies-to: [infra, deploy, observability]
projects: [all]
severity: warning
phase: [build, deploy]
last-validated: 2026-05-12
---

# Pattern: n8n Production Patterns

Hard-won n8n + Postgres patterns from the content-system signal pipeline. These constraints aren't documented in n8n's UI — every one of them swallowed a session.

## n8n Code node hard limits

- **60-second wall.** n8n cloud's JS task runner kills any Code node that runs longer than 60s with `Task execution timed out after 60 seconds`. Independent of `this.helpers.httpRequest({ timeout: 300000 })` — the inner request can have a 5-minute timeout but the Code node itself dies at 60.
- **Workaround:** put slow external calls (Apify run-sync, Firecrawl crawl, big LLM) in a dedicated **HTTP Request node** (uses workflow timeout, default 5min). Put post-processing in the Code node. Pattern: `Schedule → HTTP "external call" → Code "filter + insert" → HTTP "telegram"`.
- **Credentials don't auto-inject.** Credentials attached to Code nodes do NOT auto-inject auth headers into `this.helpers.httpRequest()` calls. The credential binding only works for native nodes (HTTP Request, Supabase node). Inside the Code node sandbox, pass keys explicitly:
  - Supabase: `apikey` + `Authorization: Bearer` headers with the actual key value
  - Anthropic: `x-api-key` header with the actual key
  - Telegram: bot token directly in the URL

## Schedule trigger fires daily by default

`scheduleTrigger` (v1.2) with only `triggerAtHour` + `triggerAtMinute` fires **every day** at that time. Workflow name alone does not enforce cadence. To fire weekly, add `triggersDay: [1]` (Mon=1) inside the interval rule. Same for monthly.

Caught when the Signal Reframe Sender (`wfdzuNkF9jEKyez4`), named "Mon 8am," fired Wed 8am ET after being reactivated Tue night. Whenever creating or auditing a "weekly" trigger, verify the rule has an explicit day-of-week field.

## Apify gotchas (sync API)

- `run-sync-get-dataset-items` has a **HARD 300s cap** the `timeout=` query param can't override.
- Search Apify Store for the exact actor name BEFORE building. `trudax/reddit-scraper` (doesn't exist; 403). Real actor: `trudax/reddit-scraper-lite`.
- Per-input shape: hit `/v2/acts/<actor>/builds/default` to read the input schema. Test once via curl with a tiny payload to see the actual response shape — including weird fields like `author: {name, profileUrl}` (not a string).
- For workflows that may exceed 300s, split into parallel HTTP nodes (one per startUrl) with `onError: continueRegularOutput` so a single 502 doesn't kill the whole workflow.

## Postgres patterns

- **`signals.engagement_score` is a generated column** (`comments * 1.5 + likes * 0.5`). POSTing a value returns `428C9` (`cannot insert a non-DEFAULT value into column "engagement_score"`). Drop it from any insert payload.
- **Verify enum/source values before writing queries.** Workflows often write `source=content_trend` while reports query `source=trend` — silent zero results. Run `SELECT count(*), source, category FROM signals GROUP BY source, category` BEFORE writing the query. Never assume field values.
- **Surface error messages in try/catch.** "0 inserted but no errors" is almost always a swallowed Postgres error code. Print the full error before assuming silent success.

## Compute facts in code, ask Claude only for prose

Don't leave `[date]`, `[count]`, `[X]` placeholders for Claude to fill — it hallucinates ("Week of Nov 18" in May, "5 accounts" pulled from thin air).

- Date headers, signal counts, distinct-account counts, format mix, week-over-week deltas → compute in the Code node, build the header string, prepend to Claude's output.
- Claude should only generate the bullet sections that require synthesis (patterns, so-what, actions).
- **Audit prompts for system/user contradictions** before deploying. System prompt saying "name handles, cite engagement numbers" while user prompt says "No engagement numbers" silently degrades quality — Claude defaults to vague generic patterns when prompts contradict.

## Auth tokens for Meta/Instagram

Personal access tokens (1hr) and long-lived (60-day) tokens both silently fail in n8n daily ingestion — `0 metrics landing` despite `success` executions because Meta's auth errors get swallowed by the workflow.

**Fix:** Create a System User at https://business.facebook.com/settings/system-users, assign it the IG page with all permissions, generate a token. **System user tokens never expire.** Never use personal access tokens for n8n Meta integrations.

## Fix coverage upstream, not the brief format

When a Signal Brief feels thin or repetitive, the cause is upstream scrape coverage, not the brief format/scoring/prompt. Verify:

```sql
SELECT threat_level, COUNT(*) FROM competitors
WHERE handle IN (SELECT DISTINCT competitor_handle FROM signals WHERE created_at >= NOW() - INTERVAL '30 days')
GROUP BY 1
```

If direct/threat tiers show 0, the scraper is the bug. Iterating on auto-pick or reframer prompts polishes whatever's there but can't fix a starved input pool.

## Pre-build checklist for any new Apify scraper

1. Search Apify Store for the exact actor name (`/v2/store?search=...`).
2. Hit `/v2/acts/<actor>/builds/default` to read the input schema.
3. Test once via curl with a tiny payload to see the actual response shape.
4. Note the sync timeout cap (Apify is 300s hard) before building.
5. THEN build the workflow.

Skipping any step costs at least one wasted exec + ~5 min.

## Cross-refs

- `verify-before-commit.md` — surface errors, don't silent-success
- `delegation-discipline.md` — use existing workflow patterns before building new
- Content-system memory: full `feedback_n8n_*.md` family
