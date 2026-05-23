---
name: scoring-design-discipline
description: When designing a tiered scoring/classification system with score-band cutoffs PLUS special per-category rules, spell out whether the special rule is a tier-demotion (can't reach higher tiers but still must clear noise floor) or a noise-floor bypass (special category appears at ANY score). They look the same in casual prose. They aren't.
type: learned-pattern
applies-to: [scoring-design, tiered-reports, classifier-output, spec-writing, self-review]
projects: [all]
severity: warning
phase: [spec, brainstorm, self-review]
trigger: [scoring-system, tiered-output, classifier, ranking, recommendation-engine]
last-validated: 2026-05-23
archetypes: [infra-config, content-pipeline]
---

# Pattern: Tier Demotion vs Noise Floor Bypass

When designing a tiered scoring/classification output with both (a) score-band cutoffs (HIGH/MEDIUM/LOW/drop) AND (b) special per-category rules ("category X always lands in LOW regardless of score"), make the interaction with the noise floor explicit.

## The two semantics that look identical in prose

**Tier-demotion semantics:**
- The special rule prevents the item from reaching higher tiers.
- The item still must clear the noise floor to appear in the report at all.
- A plugin+plugin pair scoring 0.10 → dropped (below 0.15 floor).
- A plugin+plugin pair scoring 0.45 → demoted from MEDIUM (its score band) to LOW.

**Noise-floor bypass semantics:**
- The special rule trumps the noise floor.
- The item appears in the report regardless of score, just placed at the special tier.
- A plugin+plugin pair scoring 0.10 → LOW (appears in report).
- A plugin+plugin pair scoring 0.45 → LOW (appears in report).

These two rules read identically in casual spec prose ("plugin+plugin pairs land in LOW"). They produce different reports. The first preserves report scannability; the second creates a guaranteed-noise channel.

## Why this matters

Surfaced during Phase 7.7a (skill consolidator) spec self-review: two rules contradicted each other.

- "LOW: 0.15 ≤ composite < 0.30, OR any plugin+plugin pair regardless of score"
- "(drop): composite < 0.15 → not in report"

A plugin+plugin pair with composite 0.10 satisfied both rules. The intent was tier-demotion (plugin+plugin pairs can't recommend `rm` because plugin skills are managed externally, so the verb is non-actionable; the demotion reflects "less actionable, not more noisy"). The wording accidentally read like a bypass — every plugin+plugin pair, regardless of how weak the signal, would have appeared in the report. Fixed inline by clarifying the demotion-vs-bypass semantics. Saved a post-ship dogfood embarrassment.

## How to apply

**When writing scoring specs:**

1. Explicitly answer in the spec: does the special rule trump the noise floor, or just trump the score-band assignment?
2. **Default to tier-demotion semantics** (special rule only affects which tier within the in-report range; noise floor still gates inclusion). Bypass semantics create a guaranteed-noise channel and need separate justification.
3. Self-review test: pick the boundary case (special-category item at the noise floor) and trace what the rule does. If you can't answer in one sentence, the rule is under-specified.

**Spec wording that's clear:**

> "Plugin+plugin pairs are demoted to LOW (cannot reach HIGH or MEDIUM). The 0.15 drop-floor still applies — pairs below 0.15 are dropped from the report regardless of source."

**Spec wording that's ambiguous (avoid):**

> "LOW: composite 0.15-0.30 OR plugin+plugin pairs."

The second phrasing collapses the demotion into the score band's OR clause, which reads as "membership in LOW is satisfied by EITHER condition" — bypass semantics by accident.

## Self-review checklist for scoring designs

Before shipping a scoring spec, answer in writing:

- [ ] What's the noise floor? (Below this, items are dropped from the report.)
- [ ] What are the tier bands? (HIGH/MEDIUM/LOW thresholds.)
- [ ] Are there special-category rules that override score-band assignment? List them.
- [ ] For each special rule: does it ALSO override the noise floor, or only the score-band assignment? Write the answer in the spec.
- [ ] Boundary trace: for each special category, what happens at composite = 0.0, 0.05, 0.15 (floor), 0.30 (LOW→MEDIUM boundary), 0.55 (MEDIUM→HIGH boundary), 1.0?

If any boundary case answer requires reasoning about TWO rules at once, the rules are too entangled. Refactor before shipping.

## Related patterns

- `audit-trail-before-speculative-fix.md` — "show the math before the verb" applies here: if the report can't tell you WHY a pair is in LOW vs dropped, the rule is too vague.
- `never-fabricate.md` — spec ambiguity often hides invented scoring logic that doesn't match what the implementation does. Walking the boundary trace exposes this.

Sourced from `feedback_tier_demotion_is_not_noise_floor_bypass.md`. Paired data point: `feedback_phase_7_2_1_score_zero_always_on_tier_a_pollution.md` — same failure mode (special rule bypassing a quality gate).

## Aggregation across populations needs a population-quality floor

Per-mode / per-cohort / per-bucket averages are noise-prone when the population includes tiny abandoned items. `/system-retro`'s per-mode aggregate (2026-05-23) included 16 "raw" sessions but many were <2 minutes / <5 tool calls — quick-quit transcripts that scored ~1/5 on every dimension because no real work happened. They dragged the raw bucket's average from a true ~3.5 down to ~2.4, manufacturing a false delta vs `/ship` (n=2, 4.0 score).

**The rule:** any time you aggregate scores across a population to compare means, define a population-quality floor: minimum-duration, minimum-tool-count, minimum-message-count, minimum-rows-of-evidence — whatever's structurally analogous in your domain. Sessions/items that fail the floor go in the RAW table for transparency, but the AGGREGATE table excludes them.

**Implementation cue:** add an env-var override (e.g. `MIN_AGG_DURATION_MIN=5`) so you can re-run the same analyzer with/without the floor and see whether the headline number is dominated by floor-filtered noise. If a 5-minute floor changes the per-mode delta by 30%+, your conclusion was probably an artifact of population mixing, not real signal.

**Apply this when:** building any /system-retro-style analyzer, A/B test reporter, cohort analysis, or before-vs-after comparison. The floor must be defended in the methodology, not silently applied.

Sourced from `feedback_session_aggregates_need_duration_floor.md`. Pairs with [[never-fabricate]] — including noise-population data in headline averages is fabrication-by-aggregation.
