---
name: n8n-build-patterns
description: n8n workflow building patterns — inspect before building, mock UX first, no fetch() in Code nodes, handle multi-item data flow
severity: warning
archetypes: [telegram-bot, infra-config]
last-validated: 2026-05-26
---

When building n8n workflows:

1. **Inspect before building:** List existing credentials via `GET /api/v1/credentials`. Inspect 1-2 existing workflows to see auth patterns. Match exactly — don't default to `$vars` when a credential exists.

2. **Mock UX first:** Before building any user-facing flow, mock the exact messages the user will see. Present the mock. Get approval. THEN build. Saves 5+ iterations.

3. **No fetch() in Code nodes:** n8n Code nodes do NOT have `fetch()`. Use `this.helpers.httpRequest({ method, url, headers, body })` instead. `fetch is not defined` at runtime.

4. **Multi-item data flow:** When multiple items flow through an HTTP Request node, the response REPLACES `$json`. Use `$input.all()` + `$('EarlierNode').all()` and iterate by index. `$('Node').first().json` returns the FIRST item, not the current one.

**Why:** Each of these was learned the hard way — 5 rebuild cycles, runtime crashes, lost data. The patterns save hours per workflow.

**How to apply:** Before any n8n build session, re-read this. The fetch() and multi-item gotchas are the most common traps.
