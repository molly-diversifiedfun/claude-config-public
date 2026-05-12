---
name: nonfiction-sourcing
description: Source every factual claim BEFORE writing it, never after. <your nonfiction project> had 71 fact-check errors discovered post-draft (Boeing plea that never happened, Patagonia growth misstated 2x, wrong-CEO attribution).
type: learned-pattern
applies-to: [content, verification]
projects: [all]
severity: blocking
phase: [build, verify]
last-validated: 2026-05-12
---

# Pattern: Source Everything in Nonfiction

The <your-project-2> manuscript: ~594 factual claims without sourcing. Subsequent fact-check found 71 errors — Boeing guilty plea that never happened, Patagonia "10x growth" that was actually 4.4x, stack ranking attributed to wrong CEO.

## Rule
Find the primary source FIRST, then write the claim. Never the reverse.

## How to apply:
- Before ANY factual claim, WebSearch for the primary source (SEC filing, court record, paper, press release)
- Include the source inline as you write — not after
- If you can't find a primary source: "I couldn't verify [X] — please check this"
- Never write a specific number, date, revenue figure, or study result from memory alone
- When feeding data to LLMs for analysis, label what each metric means — bare numbers cause confabulation

## Also applies to:
- Content captions with specific claims
- Competitive research
- Any deliverable with factual assertions

## Enforcement
- CARL WRITING_RULE_5 (personal facts)
- Memory file: feedback_nonfiction_sourcing.md
- Memory file: feedback_llm_data_labeling.md
