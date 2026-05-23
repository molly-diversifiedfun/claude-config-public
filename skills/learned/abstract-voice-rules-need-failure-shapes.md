---
name: abstract-voice-rules-need-failure-shapes
description: "Abstract voice/structural rules (\"one sentence\", \"no rhetorical questions\") fail on strong models — Opus 4.7 / Sonnet 4.6 satisfy the letter while violating the spirit. Extend the bootloader-lessons pattern (explicit BANNED phrases > abstract rules) to structural rules: list 3-7 BANNED SHAPES + worked compliant + worked violation + mechanical self-check."
type: learned-pattern
applies-to: [prompt-engineering, voice, claude-ai-skills, ai-build-partner, bootloader-design, llm-prompt-rules, chatgpt-apps]
projects: [all]
severity: warning
phase: [design, build, test]
last-validated: 2026-05-20
archetypes: [brand-content]
---

# Abstract Voice Rules Don't Bite on Strong Models — Add Failure Shapes

**Origin:** 2026-05-19 Dana smoke `/ship` run (`.ship/2026-05-19-dana-rubric-and-fixes/`). Phase B1 root-cause diagnostic on Opus 4.7 turn-2 "STRUCTURAL CONTRACT" miss.

## The pattern

Opus 4.7 emitted the right structural tokens (`**Do this:**`, `**Why:**`) — LAYER 6.5 was loaded and parsing. The failure was on the sub-rule "ONE sentence":

> `**Do this:** Run /<your-first-brand-coach> discovery — your project shape (4 years of notes → guide) lands cleanly in Path 3 (Resurrection) or Path 2 (have idea, need plan), and Discovery picks the right one in 5 min.`

Grammatically *one* sentence. Functionally a multi-clause stack with parenthetical + em-dash join + trailing "and" clause. Opus's interpretation of "one sentence" was technically correct and behaviorally wrong.

## Why abstract rules fail here

`feedback_gpt_bootloader_design_lessons.md` documents this for **phrases** ("don't pre-emptively diagnose" got ignored; explicit BANNED list bit). This run proves the same is true for **structural rules**. "One sentence" is an interpretable abstraction; "no em-dash clause-join, no parenthetical aside, no subordinate which/because tail, no two-action list" is mechanical.

A strong model will satisfy the letter of an abstract rule while violating the spirit. The fix isn't more emphasis ("ABSOLUTELY one sentence!"). The fix is to name the **shapes that violate** the rule.

## What worked (1-iteration bite)

LAYER 6.5 now carries a "ONE-SENTENCE CONTRACT (BLOCKING)" block with:

1. **4 explicit failure shapes** — clause-join with `and`/`—`/`;`; parenthetical aside; subordinate `which`/`because` tail; two-action lists.
2. **One compliant worked example** — `**Do this:** Run /<your-first-brand-coach> discovery now.`
3. **One violation worked example** — Opus's actual failure, verbatim and labeled.
4. **5-step mechanical self-check** — count periods, check parens, check clause-joins, check em-dashes, check trailing `and`.

Iteration 3 Opus turn 2: 6/6 PASS (was 4/6 before).

Same approach worked for the Sonnet rhetorical-question fix: Rule 10 of `02-voice-dna.md` got 7 verbatim BANNED examples (#1 = the actual Sonnet output: `"Which one is louder right now?"`), 5 compliant replacements, and "the test" diagnostic rule (compliant questions present finite named options).

## The generalizable rule

For any voice/structural rule in a Claude.ai skill bootloader or methodology doc:

| Layer | Abstract | Mechanical |
|---|---|---|
| Statement | "One sentence" | "No em-dash clause-join, no parenthetical, no trailing `and`" |
| Examples | (none) | 1 compliant + 1 violation, verbatim |
| Self-check | (vibes) | 5-step countable test |

**If the rule can be satisfied by a model that's gaming the letter, it's still abstract. Add shapes.**

## How to apply

When writing or auditing a voice/structural rule:

1. Write the abstract version first (it's the headline).
2. Ask: "could a smart writer produce text that technically satisfies this but obviously violates the intent?" If yes, the rule is abstract.
3. Append 3-7 BANNED SHAPES — concrete, mechanical, countable.
4. Append 1 compliant worked example.
5. Append 1 violation worked example (ideally the actual failure that surfaced the issue, attributed).
6. Append a mechanical self-check the model can run before emitting.
7. Edit canonical doc AND bootloader/SKILL.md together (per `feedback_gpt_bootloader_design_lessons`).

## Canonical exemplars

- `~/github/claude-skills/ai-build-partner/kit-files/00-master-system-prompt.md` LAYER 6.5 ONE-SENTENCE CONTRACT block
- `~/github/claude-skills/ai-build-partner/kit-files/02-voice-dna.md` Rule 10 Rhetorical-question BANNED EXAMPLES subsection
- `~/github/claude-skills/ai-build-partner/SKILL.md` core rule #9 mirror

Pairs with `mass-rewrite-mechanics.md` (mechanical > abstract for batch edits) and `voice-and-content-rules.md` (voice contract baseline).
