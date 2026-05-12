# Definition of Done

Every task — feature, fix, migration, deploy — is NOT done until all applicable items are complete. Execute ALL items autonomously after completing the code. Do not list remaining items and ask permission — just do them. Do not wait to be asked.

## Checklist

### Code
- [ ] Implementation complete and working
- [ ] Tests written and passing (80%+ coverage for new code) — tests ship IN THE SAME COMMIT as the feature, not as a follow-up
- [ ] No lint/type errors introduced (run `npm run check` on changed files)
- [ ] Security checklist passed (see `rules/common/security.md`) — no hardcoded secrets, inputs validated, no injection vectors

### Verification (NON-NEGOTIABLE)
- [ ] Agent output reviewed before staging — READ every file an agent produced, don't just check it exists
- [ ] For content: grep for 47, banned PM jargon, wrong handle (@your-handle not @your-wrong-handle), pillar/content label match
- [ ] For code: read the diff, verify it matches spec acceptance criteria
- [ ] Content QA pipeline run on content files (content-qa-guarded.sh runs automatically, but also spot-check)

### Documentation
- [ ] CLAUDE.md updated if new tables, edge functions, hooks, services, skills, or patterns added
- [ ] ADR created if architectural decision was made (`docs/decisions/`)
- [ ] Access matrices / permission tables updated if auth changed
- [ ] Specific docs updated per change type (see mapping below)

#### Doc Update Mapping — which change triggers which doc

| If you touched... | Update these docs |
|---|---|
| `supabase/functions/` (new/modified edge function) | `docs/edge-functions.md`, CLAUDE.md edge function count |
| `supabase/migrations/` (new table or column) | `docs/database-schema.md`, CLAUDE.md table count |
| `src/services/` (new service) | `docs/services.md` |
| `src/hooks/` (new hook) | CLAUDE.md hooks list |
| RLS policies, roles, auth changes | `docs/roles-and-permissions.md` |
| New integration provider | `docs/integrations.md`, CLAUDE.md integrations table |
| New feature or page | `docs/features.md` or `docs/features/<area>.md` |
| Deployment process change | `docs/deployment.md` |
| pg_cron, Vault, infrastructure | `docs/architecture.md`, `docs/deployment.md` |
| `~/.claude/hooks/` (new or modified hook) | CLAUDE.md hooks section, `rules/common/agents.md` hooks section |
| `~/.claude/rules/` or `~/.carl/` (new rule/domain) | CLAUDE.md if new domain, CARL manifest if new domain |
| `~/.claude/skills/` (new or modified skill) | CLAUDE.md skill collections section |
| `~/.claude/settings.json` | ALWAYS read before editing. If hooks/plugins changed, update CLAUDE.md |
| Content files (captions, carousels, memes) | Run content-qa pipeline, verify pillar ratios, check calendar tracker |

### Tracking
- [ ] GitHub issue updated or closed
- [ ] TASKS.md updated (mark complete, add discovered work)
- [ ] HANDOFF.md updated if session-relevant
- [ ] `docs/roadmap-tracker.html` updated (progress %, track items, blockers)
- [ ] Memory updated if new patterns, preferences, or corrections discovered (`/update-memory`)

### Decisions
- [ ] Key decisions logged (in ADR, audit doc, or commit message)
- [ ] Trade-offs documented (what was chosen, what was rejected, why)

### Deploy
- [ ] Migration applied to target environment
- [ ] Rollback plan documented
- [ ] Verification query run to confirm changes landed
- [ ] Manual test checklist updated for items that can't be verified programmatically (`docs/testing/manual-test-checklist.md`)

## When to Skip

Not every item applies to every task. Use judgment — BUT the following are NEVER skippable:

**Always required (no exceptions):**
- Verification: read agent output before staging
- TASKS.md: mark complete, add discovered work
- HANDOFF.md: update if >20 tool uses in session
- Tests: ship with the feature, not as follow-up

**Skip only if genuinely N/A:**
- Quick typo fix? Code + tracking is enough.
- Database migration? Code + docs + deploy + tracking — all of it.
- Security change? Everything, plus access matrix.
- Config-only change (hooks, rules, CARL)? Config docs + tracking.

The rule: if someone asked "is this done?", would you have to go back and do more work? Then it's not done yet.
