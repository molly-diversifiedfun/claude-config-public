---
description: Full pipeline mode — memory-aware /ship v3 (Phase 8.0 — Smart /ship: auto-scope + superpowers gates).
---

# /ship — smart scope-aware shipping pipeline

`v3` (Phase 8.0, 2026-05-23) — `/ship` now classifies your ask into one of 4 scope tiers and runs only the stages that fit. Each stage is explicitly bound to a superpowers skill at the gates where discipline matters most.

Usage: `/ship [feature description]`

## Stage 0 — Scope classify [NEW v3, REQUIRED]

Run:

```bash
python3 ~/.claude/scripts/ship-scope-classify.py "<the feature description>"
```

Returns `{"scope":"S|M|L|XL","rationale":"..."}`. Persist the result:

```bash
mkdir -p .ship/<date>-<slug> && echo "$RESULT" > .ship/<date>-<slug>/scope.json
```

Tiers:
- **S** — single-file fix, typo, config tweak, dep bump. → Stages 6 + 9 only.
- **M** — feature with tests, refactor, new endpoint. → Stages 1 + 2 + 3 + 6 + 7 + 9 + 10 + 11.
- **L** — multi-component feature, migration, UI overhaul. → Stages 1 + 2 + 3 + 4 (if UI) + 5 (if research) + 6 + 7 + 8 + 9 + 10 + 11.
- **XL** — architectural change, new service, breaking redesign. → All stages + ADR mandatory + memory-keeper double-pass.

If the classifier output looks wrong, override manually by editing `scope.json` before continuing. Kill switch: `SHIP_SCOPE=off` → defaults to M.

## Stage → superpowers binding (v3)

Each stage has an explicit superpowers Skill it MUST invoke as the gate. The Skill itself contains the discipline; /ship is the wrapper that ensures it fires.

| Stage | Superpowers Skill | When |
|---|---|---|
| 2 — brainstorm scope | `superpowers:brainstorming` | scope ≥ M and spec is ambiguous |
| 4 — write plan | `superpowers:writing-plans` | scope ≥ M (always for multi-step work) |
| 6 — TDD | `superpowers:test-driven-development` | ALWAYS unless ask is docs-only |
| 7 — subagent execution | `superpowers:subagent-driven-development` | scope ≥ L with 3+ independent tasks |
| 9 — verification | `superpowers:verification-before-completion` | ALWAYS before smoke claim |
| 10 — request review | `superpowers:requesting-code-review` | scope ≥ M |
| 11 — finish branch | `superpowers:finishing-a-development-branch` | scope ≥ M (decide PR vs direct merge) |

These bindings are doc-enforced in V1. V2 (Phase 8.1) will add hook gating via `ship-phase-gate.sh` — until then, the orchestrator (you) is responsible for invoking the Skill at each gate.

## Stage 1 — Pre-flight (memory-keeper) [SKIP IF S]

1. Dispatch @memory-keeper with the feature description.
2. memory-keeper writes `.ship/<run>/patterns.md` per its agent definition.
3. Confirm inferred tags with the user. Edit if wrong.
4. Gate: patterns.md exists, ≥1 pattern listed, project memory referenced.

## Stage 2 — Brainstorm [SKIP IF S; SKIP IF SPEC OBVIOUS]

**Invoke `Skill(superpowers:brainstorming)`** with the feature description. Output to chat — explore user intent, requirements, design before any spec writing. If the ask is unambiguous on intent + scope, skip and note "spec is obvious" in the run log.

## Stage 3 — Spec [SKIP IF S]

@product-lead writes the spec, **passing patterns.md as required reading** + brainstorm chat summary if Stage 2 ran. Spec includes: user stories, API contracts, data model, error states, privacy/compliance. For XL, also writes an ADR at `docs/decisions/NNN-<title>.md`.

## Stage 4 — Design [SKIP IF NO UI; SKIP IF S]

@designer creates design spec. Then **invoke `Skill(superpowers:writing-plans)`** to write the implementation plan at `.ship/<run>/plan.md`. The plan IS the contract for Stages 6-9.

## Stage 5 — Research [SKIP IF NO OPEN UNKNOWNS; OPTIONAL FOR M]

@tech-researcher / @market-researcher investigate unknowns. Add findings to `.ship/<run>/research.md`.

## Stage 6 — TDD [REQUIRED UNLESS DOCS-ONLY]

**Invoke `Skill(superpowers:test-driven-development)`**. Tests written and FAILING first; then implementation makes them pass. For S scope, this is the FIRST coding step — no prior stages needed. Tests ship in the same commit as the feature, never as a follow-up.

## Stage 7 — Implementation [SKIP IF S; for S, this collapses into Stage 6]

@engineer implements. For scope ≥ L with 3+ independent tasks in plan.md, **invoke `Skill(superpowers:subagent-driven-development)`** to dispatch parallel workers. @debugger on-call if BLOCKED.

## Stage 8 — Review [SKIP IF S; SKIP IF M with no auth/payment/input handling]

@reviewer Tier 2 review (escalate to Tier 3 if scope=L or XL). @security audit if auth/payments/input handling. @content-qa runs if content tags.

## Stage 9 — Deploy + Smoke [REQUIRED for all scopes that produce code]

1. **Invoke `Skill(superpowers:verification-before-completion)`** BEFORE claiming the work is done. Evidence before assertions — name what command you ran, what output landed.
2. Engineer pushes to deploy target.
3. Append `## Deploy attempt N` to `.ship/<run>/deploy-log.md` per push.
4. Before deploy 3, engineer MUST declare observability:
   - `## Observability: <how I can see runtime logs>`
   - If logs are opaque, buy observability OR pivot.
5. Real-runtime smoke via `everything-claude-code:e2e-runner` for code paths, OR local-invocation against prod creds per `feedback_local_invocation_when_railway_http_down`.
6. Append `## Smoke test: <result>` to deploy-log.md.
7. Gate (hook): `ship-phase-gate.sh` checks 3-deploy-rule, observability, smoke.

## Stage 10 — DoD walk + handoff [SKIP IF S; LIGHT for M]

@project-manager performs the Definition of Done walk AND writes the handoff updates directly. **No drafts, no "inline reminders" — the agent's job is to land the edits.**

Then **invoke `Skill(superpowers:requesting-code-review)`** to verify the change meets the originally-stated requirements before commit.

### Step 10a — DoD checklist (per `rules/common/definition-of-done.md`)

- [ ] Implementation complete + tests in same commit (≥80% coverage on new code)
- [ ] Lint/type checks clean (`uv run ruff check` / `npm run check` per stack)
- [ ] Registry contract — if new module behind any registry, grep `**/registry.py` confirms the import. Integration test asserts membership.
- [ ] Production smoke after deploy — exercise the new path in real conversation OR local one-shot against prod
- [ ] Security: no hardcoded secrets, inputs validated, no injection vectors
- [ ] Agent output reviewed before staging — read every file an agent produced
- [ ] GitHub issue updated or closed; PR description has summary + test plan

### Step 10b — Doc updates (DIRECT EDITS, NOT DRAFTS)

| Touched | Update |
|---|---|
| New edge function | `docs/edge-functions.md`, CLAUDE.md count |
| New migration / table / column | `docs/database-schema.md`, CLAUDE.md count |
| New service | `docs/services.md` |
| New hook | CLAUDE.md hooks list |
| RLS / auth change | `docs/roles-and-permissions.md` |
| New integration | `docs/integrations.md`, CLAUDE.md table |
| Deploy process change | `docs/deployment.md` |
| New rule / hook / skill | CLAUDE.md + relevant rules file |
| Audit row resolution | Mark closed in `docs/audit/<date>-findings.md` |
| ADR-worthy decision | `docs/decisions/NNN-short-title.md` |
| All non-trivial PRs | `HANDOFF.md` top status line + new row in arc table + Open Items + tests delta + main-clean SHA |
| All non-trivial PRs | `TASKS.md` mark done + carry forward discovered work |

### Step 10c — Memory + roadmap

- `MEMORY.md` index updated if Stage 11 capture added entries (Stage 11 owns this).
- `docs/roadmap-tracker.html` updated if the PR ships a roadmap story.

**Reporting:** project-manager outputs a verification summary listing files touched + DoD items confirmed. Genuinely N/A items get named with reason.

## Stage 11 — Capture + finish [SKIP IF S; SKIP IF zero learnings emerged]

1. Dispatch @memory-keeper for capture per its agent definition.
2. memory-keeper drafts feedback files into `.ship/<run>/draft-feedback/`.
3. Asks the user Q1 per draft + Q2 (surprises) + Q3 (synthesis candidate).
4. Approved drafts move to `memory/`, MEMORY.md updated.
5. **Invoke `Skill(superpowers:finishing-a-development-branch)`** to decide merge strategy (PR vs direct), then `/commit-push-pr` if PR path.

## Compressed paths by scope

| Scope | Stages run | Required skills |
|---|---|---|
| S | 6 + 9 | `tdd`, `verification-before-completion` |
| M | 1 + 2 + 3 + 6 + 7 + 9 + 10 + 11 | `brainstorming`, `tdd`, `verification-before-completion`, `requesting-code-review`, `finishing-a-development-branch` |
| L | 1 + 2 + 3 + 4* + 5* + 6 + 7 (+ `subagent-driven-development`) + 8 + 9 + 10 + 11 | all of M + `writing-plans` (Stage 4) + `subagent-driven-development` (Stage 7) |
| XL | All stages, ADR mandatory in Stage 3, memory-keeper double-pass (Stage 1 + Stage 11) | all of L |

*Stage 4 only if UI; Stage 5 only if open unknowns.

## Final step

@project-manager produces completion summary + cost report.

Auto-proceeds between phases unless an agent flags concerns (DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED).

## Examples

```
/ship fix typo in src/auth.ts error message     # → S: Stages 6+9
/ship add Slack OAuth to landing page            # → M: Stages 1+2+3+6+7+9+10+11
/ship migrate payment flow Stripe Checkout → Elements   # → L: all of M + 4+5+7-sdd+8
/ship split monolith into 3 microservices behind gateway   # → XL: all + ADR + double memory pass
```

## Kill switches

- `SHIP_SCOPE=off` — disable classifier; defaults to M.
- `SHIP_PHASE_GATE=off` — disable Stage 9 hook gates (still run the stage; just don't enforce).
