---
name: research-and-history-discipline
description: Cross-project discipline for prompt/config regressions, migration safety, deploy verification, and framework-selection auth audits. Synthesizes 4 feedback patterns from the 2026-05-20 → 2026-05-22 <your-agent-project> arc.
applies-to: [prompt-engineering, database-migrations, cloud-deploy, framework-selection, llm-agent-projects]
projects: all
severity: warning
phase: [build, ship, review]
last-validated: 2026-05-22
---

# Research and History Discipline

Four cross-project patterns that surfaced when <your-agent-project>'s Bubbles regressed,
the prompt-trim turned out to have dropped behavior anchors, migrations
hit a schema-drift wall on apply, and the framework-reuse audit kept
returning the same DQ. They share a structure: **you can't fix the
present without consulting the past.**

## 1. Multi-version diff > 2-point diff for behavior-shaping files

When a long-lived behavior-shaping file (system prompt, ADR, config,
brand voice doc) starts producing worse output, **do not just diff
against the immediately-prior version.** Sample N inflection points
across the file's history — every named "fix" or "feat" commit. The
2-point diff finds compressed phrases; the multi-point diff finds the
iterative additions that the suspect commit didn't know it was undoing.

**Mechanic:**

```bash
git log --all --pretty=format:"%h %ad %s" --date=short -- <file>
# Pick 4-6 inflection points: original, +major feature, +another, suspect trim, current
for sha in <sha1> <sha2> ...; do
  git show "${sha}:<file>" > "/tmp/v_${sha}.md"
done
diff /tmp/v_<old>.md /tmp/v_<new>.md  # adjacent pairs
grep -E "(anchor1|anchor2|anchor3)" /tmp/v_*.md  # presence/absence sweep
```

**Reverse application:** when WRITING a "perf: trim X" commit, run this
pattern in the opposite direction — sample the last 4-6 versions you're
consolidating from, and explicitly note in the commit body which anchors
you considered + cut vs kept. That's the diff a future debugger will
reach for.

Source: 2026-05-22 prompt regression session. PR #177 trimmed
`system.md` 222→98 lines for token savings. PR #183 had to restore 6
behavior anchors that the 2-point diff (post-trim vs current) didn't
reveal — only a 6-point diff across `git log -- system.md` showed the
iterative additions PR #177 had compressed away.

## 2. Query live schema's NOT NULL + CHECK before copying an INSERT pattern

When a new migration includes an INSERT modeled on a prior migration's
INSERT, **the prior migration's column list is not authoritative.**
Between when it ran and when yours runs, the schema may have gained NOT
NULL constraints, CHECK constraints, or new required columns. Query
live schema first; the 3-second query saves a rollback cycle.

**Mechanic:**

```sql
-- Inspect column constraints
SELECT column_name, is_nullable, data_type, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='<table>'
ORDER BY ordinal_position;

-- Inspect CHECK constraints
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid='public.<table>'::regclass AND contype='c';

-- Sample a recent row for canonical shape
SELECT * FROM <table> ORDER BY <ts_col> DESC LIMIT 1;
```

Source: 2026-05-21 migration `0045_team_threads`. Needed 3 apply
attempts — first failed on `memory_scope='persona_scoped'` (real values
were `{self_only, parent_session, root_goal, persona_full}`); second
failed on `agent_events` NOT NULL columns that didn't exist when the
prior migration ran. Both were copy-paste-from-prior-migration drift.

## 3. Cloud env var changes don't always trigger auto-deploy

Setting a new env var on Railway / Vercel / Fly / similar PaaS
dashboards does NOT reliably auto-trigger a new deployment. The
Variables tab saves the value, but many platforms batch env changes
until you click "Deploy" / "Redeploy" manually.

**Mechanic:**

After ANY env-var add/edit for a production service:

```bash
# Check that a fresh deploy with a new ID has started:
# (Railway example; adapt to provider)
mcp__railway__list_deployments
# If the latest deploy's createdAt is older than your env-var save,
# the platform didn't auto-redeploy. Trigger one manually.
```

Or simpler rule: **if a service depends on a freshly-added env var for
boot, always trigger an explicit redeploy and verify the new deploy's
commit SHA matches `main`'s HEAD before declaring the change live.**

Source: 2026-05-22 CLAUDE_CODE_OAUTH_TOKEN incident. User added the
token to Railway env, said "added", I checked deployments 40 min later
and Railway hadn't auto-redeployed. Next chat session failed with the
same synthetic "Not logged in" because the running container didn't
have the new env var. Manual redeploy fixed it instantly.

Cross-reference: paired with `verify-deploy-sha-before-flipping-dependent-schedule`
(same idea applied to crons; this is the env-var variant).

## 4. Subscription-first auth disqualifies most multi-agent frameworks

When using Anthropic via subscription (`CLAUDE_CODE_OAUTH_TOKEN` from
`claude setup-token`) instead of metered API (`ANTHROPIC_API_KEY`),
most multi-agent / agent-orchestration frameworks are hard-DQ'd. As of
Feb 2026, Anthropic explicitly closed third-party OAuth tooling
(`claude-code` issue #42106 closed "not planned") and the Messages API
rejects OAuth tokens.

**The DQ list (verified 2026-05-22):**

- CrewAI, smolagents, AWS Strands, Microsoft Agent Framework, AutoGen,
  Pydantic AI, LangGraph, OpenAI Agents SDK — all force
  `ANTHROPIC_API_KEY` against the Messages API.
- Mastra defaults to a TOS-grey OAuth routing pattern (the exact thing
  Anthropic banned); not safe.
- Inngest AgentKit Anthropic provider reads `ANTHROPIC_API_KEY`.

**What IS subscription-compatible:**

- **Claude Agent SDK** (Anthropic's official Python SDK that spawns the
  `claude` CLI subprocess). The ONLY framework that respects the
  subscription path.
- **Infra-layer tools** (Restate, DBOS, Temporal, etc.) — they're
  language-agnostic durable execution layers; your Python code inside
  decides auth. Subscription-first stays intact.
- **Tool-layer tools** (Composio for OAuth-glued integrations) — they
  don't touch your LLM auth.

**Selection rule:** when evaluating "should we use framework X?",
**first ask "does X let me call Claude through CLAUDE_CODE_OAUTH_TOKEN
without going through the Messages API?"** If no, it's a hard DQ for
subscription-first projects — no matter how elegant the rest of the
framework is. The cost ceiling matters more than the architectural
elegance.

**Re-check trigger:** Anthropic announced "Agent SDK credits" launching
2026-06-15. Re-evaluate the DQ list that day; the credit may open up
third-party frameworks if it's not Agent-SDK-exclusive.

Source: 2026-05-21 + 2026-05-22 framework-reuse audit covering 12+
platforms (Mastra, Inngest, Pydantic AI, Claude Agent SDK, Restate,
Temporal, Cloudflare Agents, LangGraph, OpenAI Agents SDK, Lindy, Relay,
Poke, CrewAI, Agno, smolagents, MS Agent Framework, AWS Strands, DBOS,
Composio, Karpo, Manus, Dust). Subscription-auth filter eliminated all
direct agent frameworks except Claude Agent SDK.

---

## The common thread

All four patterns share: **the past constrains the present in ways
the present can't see without explicitly looking.** Prompt history.
Schema history. Platform-deploy history. Anthropic-policy history.
None of these are surfaced by default; all of them must be queried
deliberately. The cost of querying is small; the cost of NOT querying
is rework, rollbacks, drift windows, and silent outages.

Related learned/ patterns: [[verify-deploy-sha-before-flipping-dependent-schedule]],
[[apply-change-set-with-real-world-drift]],
[[no-architectural-fiction-constants]].
