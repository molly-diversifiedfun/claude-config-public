---
name: dogfood-by-using-the-system-to-document-itself
description: When you've just built a system, the first real run should be using that system to produce its own documentation/release artefact. Forces every gap to surface during the most-attention moment.
type: learned-pattern
applies-to: [process, verification, build]
projects: [all]
severity: warning
phase: [test, deploy, capture]
trigger: [first-real-run, acceptance-test, post-build-validation]
last-validated: 2026-05-10
---

When a new system or pipeline ships v1, the first real production run should be using that system to produce its own documentation, marketing site, release notes, or other artefact about itself. The recursive load forces every gap to surface during the moment you have the most attention to fix them.

## Why this works

1. **Forced realism.** A synthetic acceptance test exercises the happy path you anticipated. Real work exposes the assumptions you didn't notice.
2. **Free dogfooding signal.** You learn what the new system feels like to use BEFORE handing it to others.
3. **The artefact has structural integrity.** Documentation produced by the documented system tends to be more accurate than documentation produced separately — the act of using it surfaces what it actually does vs what the spec said.
4. **The gaps are pre-paid.** Anything that breaks gets fixed while you still have full context, instead of accreting as future-you's problem.

## Concrete instances

- **Ship Pipeline v2 (2026-05-10):** Built the 11-stage memory-aware /ship pipeline, then immediately ran `/ship` on the request "build a beautiful HTML doc site for this whole setup" as the Phase 7 acceptance test. The hook gate fired live. Stage 1 wrote `patterns.md`. Stage 9's `deploy-log.md` got generated. Stage 11 captured new feedback. Verified the ancestor-walk fix in production. Surfaced one major gap that would have shipped silently otherwise: the system was designed without asking who the audience was for the doc site.

## How to apply

After shipping any v1 of a system, command, or pipeline, the next concrete task should be: produce something *about* the system *using* the system. Not a synthetic test fixture. Real output you'd ship publicly.

If the system has external dependencies that prevent self-application (e.g., a tool you haven't deployed yet), still scope the first real use to a high-stakes artefact rather than a low-stakes test. The point is forcing the production conditions early.

## When NOT to apply

- If self-application creates a circular dependency that can't terminate (e.g., a build system that needs itself to build itself before it can be tested). Bootstrap with a synthetic minimum first, THEN dogfood.
- If the artefact is so trivial that real-world signal is masked by triviality (a "hello world" deploy doesn't dogfood much). Pick something with enough surface area to exercise the system.

## Related patterns

- `learned/verify-before-commit.md` — dogfooding is verification at the system level
- `learned/deploy-iteration-discipline.md` — the 3-deploy rule applies during the dogfood run too
