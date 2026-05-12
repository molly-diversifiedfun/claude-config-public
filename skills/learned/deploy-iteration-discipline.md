---
name: deploy-iteration-discipline
description: 3-deploy rule. Buy observability before deploy 3 OR pivot to a stack you control. Module hygiene survives framework swaps.
type: learned-pattern
applies-to: [deploy, infra, observability]
projects: [all]
severity: blocking
phase: [build, deploy]
trigger: [3-deploy-rule, opaque-runtime, framework-pivot, change-set-drift]
last-validated: 2026-05-08
---

# Pattern: Deploy Iteration Discipline

When something doesn't work after `git push`, the next push is usually wasted. This pattern names the conditions under which iteration produces no new signal — and what to do instead.

## The 3-deploy rule

If you've shipped 3+ deploys against an opaque framework without convergence, **the framework is the problem.** Pivot to a stack you fully control before deploy 5.

<your-personal-ai-project> Phase 4.6 (2026-05-06): 5 deploys debugging openclaw plugin claims/dmPolicy/device-pair/agent routing. Path C (rip out openclaw, plain grammY + Anthropic SDK direct) shipped in 30 min and worked first ping. Pivot signal was there at deploy 4 — pushing felt like progress but Railway's log panel froze at gateway-startup with no new info per push.

## Before deploy 4, ask:

1. **Will the next iteration give me a NEW signal, or am I re-running the same experiment?** If you can't articulate the new signal, don't push.
2. **Can I see runtime logs?** If logs are opaque (Railway log panel frozen, Vercel runtime hidden, framework abstractions), every blind push burns time at constant entropy.
3. **How many LoC does the framework save vs. how much hidden behavior do I take on?** Heavy abstraction + opaque runtime = high cost when something breaks.

## What "opaque" looks like

- Log panel ≠ live tail. Railway's deploy-logs UI does not auto-tail by default. Same with Vercel, Fly.
- Stock plugins claim inbound silently (openclaw `device-pair` ate Telegram traffic before the custom plugin saw it). Confirm what claims your traffic before assuming your hook fires.
- Stdlib logging in FastAPI/uvicorn needs `logging.basicConfig(force=True)` in lifespan — uvicorn pre-configures root and silently swallows your INFO/WARN otherwise.

## Module hygiene survives framework swaps

<your-personal-ai-project>'s `persona-wrap` skill (loader + preLlmCall + postLlmCall) worked identically inside an openclaw plugin OR called directly from a grammY handler. **Design for the module boundary, not the framework's contract.**

## When applying a pre-built change-set: expect spec drift

Specs written hours/days earlier drift against the real world: PyPI versions move, repo isn't initialized yet, accounts not provisioned, env vars stale.

- Apply in dependency order. Resolve only what's local + reversible without permission (file edits, `git init` in a folder with no remote, conservative version relaxation).
- When relaxing a version constraint, document the relaxation in commit message AND HANDOFF — name the spec line you deviated from and why.
- For shared-state actions (creating a GitHub remote, pushing, provisioning accounts), DO NOT improvise. Make the local commit, write a "what's blocked on you" section in HANDOFF, and stop.
- Flag spec drift even when the workaround was easy. The next session should see "spec said X, actual was Y" so the spec gets corrected, not silently rotated around.

## Vercel/Railway/build deploy gotchas (Content OS, 2026-04-30)

- **tsc is stricter than vite build.** Vercel runs `tsc -b && vite build`. Local `vite build` skips tsc. Always run `npx tsc -b --noEmit` before deploying.
- **Symlinks break Vercel builds.** `public/unstuck → ../` works locally, ENOENT on Vercel. Remove symlinks from `public/`.
- **VITE_ env vars must be set in deploy target.** Without them the app renders blank (Supabase client throws at startup).
- **Supabase generated types lag schema.** After adding tables, regen types or `as any` cast on `supabase.from()`.
- **`vite envDir`** pointing to parent dir works locally but not on Vercel — use `__dirname`.
- **Railway `[deploy].startCommand`** overrides Dockerfile CMD and runs in exec form, so `$PORT` won't shell-expand. Drop `startCommand` or wrap in `bash -c`.

## Local first when secrets exist

When `.env.local` is permission-denied to me, I can't run a real local agent test against the LLM API — so shipping to prod blind. Instead: ask user to run the local smoke command themselves with `! npx ...` so we get the LLM-loop signal before deploying.

## Read project memory at session start

Project-scoped memory (`~/.claude/projects/-*-{project}/memory/project_*.md`, `reference_*.md`) captures gotchas (Supabase MCP scope, Railway TTY blockers, Playwright auth fallback, GCP project quota) that prevent re-deriving the same workarounds. Read it before the first tool call on the project's code, not after.

## Cross-refs

- `secrets-routing.md` — Raw Editor leak when driving Railway via Playwright
- `systematic-shortcutting.md` — pushing-feels-like-progress as a shortcut
- <your-agent-project> memory: `feedback_logging_visibility_in_railway_dockerfile.md`, `feedback_railway_deploy_overrides_dockerfile.md`
