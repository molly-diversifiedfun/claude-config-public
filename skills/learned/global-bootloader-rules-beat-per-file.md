---
name: global-bootloader-rules-beat-per-file
description: "Behavioral rules that apply to N command/template files MUST live in the always-in-scope bootloader, NOT in individual command files. Per-file rules only fire when their file is retrieved; bootloader rules apply to every turn. The Don't-echo-T-codes rule lived in T05.md alone and was violated on T17/T18 by every model tested — promoting to bootloader bit on gpt-5 in one iteration."
type: learned-pattern
applies-to: [bootloader-design, chatgpt-gpt, claude-ai-skills, command-files, ai-skills, prompt-engineering]
projects: [all]
severity: blocking
phase: [design, build, bootloader-design]
last-validated: 2026-05-20
archetypes: [content-pipeline, brand-content, always-on]
---

# Behavioral Rules That Cross Commands Live in the Bootloader, Not the Command File

**Origin:** 2026-05-20 paid Ship It Kit GPT smoke iterations. The "Don't echo T05 back at the buyer" rule lived only in `T05.md` — buried in opening prose. When other T-templates fired (T17, T18), the rule wasn't in scope. Both Anthropic models AND OpenAI gpt-4o committed the violation on the cross-command turn.

## The structural reason

ChatGPT Custom GPTs (and similarly-architected Claude.ai skills) split context across two surfaces with different attention guarantees:

| Surface | Scope | Attention |
|---|---|---|
| **Bootloader / Instructions** | Always in scope | Fully attended every turn |
| **Knowledge / command files** | Retrieved only when relevant | Attended only when surfaced |

A rule in `T05.md` fires only when the model retrieves `T05.md`. On any other turn, the rule is invisible. The model has no memory of it, no constraint from it, no way to apply it.

If the rule's intended scope crosses commands — e.g. "don't echo any T-code back," not just T05 — the file-local placement is structurally guaranteed to leak.

## The empirical from 2026-05-20

| Placement | gpt-5-chat-latest | gpt-4o | Anthropic models |
|---|---|---|---|
| Per-file rule in T05.md only | 0% adherence on T17/T18 firing | 0% adherence | 0% adherence |
| Bootloader NEVER list with worked example | PASS | Still leaks (weaker model) | PASS |

One iteration. The rule moved from buried-in-T05 to a NEVER-list bullet in HARD RULES with the literal failure shape (`"Cool, running T17!"` → BANNED) and gpt-5 flipped from FAIL to PASS on the affected criterion.

## How to apply

When you're designing a behavioral constraint for a multi-command AI surface:

1. **Ask: "Does this apply to one command or many?"** Be honest. Most cross-command rules masquerade as per-command rules because they were discovered while debugging a specific command.
2. **If many** → put it in the bootloader. Even at the cost of bootloader character budget. The 8000-char ChatGPT GPT Instructions ceiling is real (see [[openai-responses-api-as-gpt-smoke]] for empirical 7920 OK / 8571 silent-rejected) — trim by compressing other prose, not by leaving cross-cutting rules under-scoped.
3. **If one** → put it in the command file's opening section. But pre-commit: "if I see the same constraint emerge on commands N=2, 3, 4, I'll promote it to the bootloader."
4. **Pair with concrete failure shapes**, not abstract phrasing. "Don't echo T-codes" is abstract; "BANNED: 'Cool, running T17!' / 'T05 fires X' — open with the template's friendly H1 instead" is mechanical. See [[abstract-voice-rules-need-failure-shapes]] for the explicit-BANNED-shape pattern.

## Concrete examples from the paid Kit ship (2026-05-20)

All four are bootloader-scoped rules that should NOT be per-file:

| Rule | Why bootloader-scoped |
|---|---|
| T-code echo ban | Applies to all 25 T-templates + 16 methodology commands |
| MOS-not-loaded deferral with Kit-side fallback names (T11/T12/T24) | Applies on any MOS-trigger turn, not just one command |
| Pricing concerns → T25/T06 mapping | Applies on any pricing-emotion turn |
| Motivational fluff ban with examples | Applies on every emotional-carve-out turn |
| No pre-announce ("Let me pull up X", "Loading the template") | Applies on every command-firing turn — added 2026-05-20 after T3 PMF smoke FAIL |

## When the rule is genuinely per-file

Some rules are correctly file-local:

- The verbatim opening of a specific template (`T05.md` opens with "Cool, let's get your One-Page Scope locked.")
- A command-specific Step 0 precondition check (`pmf.md` Step 0 scans User Context Section B for ≥30-day ship date)
- A command-specific exit clause (`T25.md` ends after the price-iteration table is locked)

If the rule is content that defines what a specific command DOES, it belongs in the command file. If it's a behavioral constraint about HOW the model responds (independent of which command), it belongs in the bootloader.

## The leak diagnostic

If a smoke surfaces a behavioral violation on command N, and the rule for that behavior lives in command file M (≠ N), the rule placement is wrong. Don't add the rule to N's file too — that's whack-a-mole. Promote to bootloader.

## Cross-references

- [[abstract-voice-rules-need-failure-shapes]] — explicit BANNED phrases > abstract rules; pairs with this pattern (the promoted rule should carry its failure shapes)
- [[openai-responses-api-as-gpt-smoke]] — the smoke surface that exposes cross-command leaks honestly
- [[llm-judge-needs-retry-and-defensive-parse]] — judge-side discipline for diagnosing whether a smoke failure is a real rule violation vs criterion-spec issue
- [[required-reading-blocks-leak-narration]] — what the bootloader is FOR; cross-cutting rules belong here
