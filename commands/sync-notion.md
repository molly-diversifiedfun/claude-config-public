Sync GitHub docs and session progress to the <your-project-1> Notion wiki.

Usage: /sync-notion [mode]

Modes:
- `progress` — Create a Build Progress entry from the current HANDOFF.md (non-technical, for Lucas)
- `docs` — Sync generated reference docs (services, tables, edge functions, hooks) to Notion
- `both` — Do both (default)

## Progress Entry

Read HANDOFF.md, translate into plain English for non-technical readers, and create an entry in the Build Progress database.

Build Progress Database:
- Data Source ID: `7e888910-ec86-4704-b2e4-947237f45173`
- Columns: Session (title), Date, Theme (1-line summary), Impact (Major/Significant/Incremental), Areas (multi-select: Security, Performance, Features, Testing, Infrastructure, Compliance, Research, Design)

Content structure:
1. **What Happened** — 2-3 sentence overview
2. **Key Wins** — Bullet points in plain English. No task IDs, file paths, or jargon. Write for someone who doesn't code.
3. **Key Decisions** — What was decided and why
4. **What's Next** — What's planned for the next session

Writing rules:
- "Found 6 backend endpoints that weren't checking if users were logged in" NOT "auth enforcement on edge functions"
- "App loads 46% faster" NOT "bundle 805→435KB via manualChunks"
- "Automated quality checks run on every code change" NOT "GitHub Actions CI pipeline"

## Docs Sync

Read the generated docs from GitHub and update the corresponding Notion pages in Engineering:

| GitHub File | Notion Page |
|---|---|
| `docs/reference/generated/services.md` | Create/update "Generated: Services Reference" under Engineering |
| `docs/reference/generated/tables.md` | Create/update "Generated: Database Tables" under Engineering |
| `docs/reference/generated/edge-functions.md` | Create/update "Generated: Edge Functions" under Engineering |
| `docs/reference/generated/hooks.md` | Create/update "Generated: Hooks" under Engineering |
| `docs/reference/generated/components.md` | Create/update "Generated: Components" under Engineering |
| `docs/reference/generated/routes.md` | Create/update "Generated: Routes" under Engineering |

Engineering section page ID: `3321662b-4358-8180-975d-ff46ae925b24`

Mark each synced page with the date: "Last synced from GitHub: YYYY-MM-DD"

## Key IDs

- Wiki Home: `3321662b-4358-817f-abcb-ea913f7c26f3`
- Product: `3321662b-4358-81ae-aba3-f59cb73b22e0`
- Research: `3321662b-4358-81d4-9015-d70e8d2f8479`
- Business: `3321662b-4358-8191-8c0d-c6771212ef19`
- Engineering: `3321662b-4358-8180-975d-ff46ae925b24`
- Launch Readiness: `3321662b-4358-813e-b260-d339ee9c5efb`
- Build Progress DB: data source `7e888910-ec86-4704-b2e4-947237f45173`
- ADRs DB: data source `3d96b48f-83bc-4a5f-9c4a-09ff0aefc414`
