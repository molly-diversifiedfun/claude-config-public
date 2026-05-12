---
name: voice-and-content-rules
description: Voice register (Kerouac × Sinek × Codie Sanchez), pillars/format mix, copy-is-sacred discipline, carousel variety rules. The cumulative voice contract for all Unstuck content.
type: learned-pattern
applies-to: [content]
projects: [all]
severity: blocking
phase: [content, verify]
last-validated: 2026-05-12
---

# Pattern: Voice Register and Content Rules

## Voice formula
Kerouac × Sinek × Codie Sanchez = stream-of-consciousness rhythm + start-with-why clarity + irreverent receipts.

Write like texting a smart friend at midnight. Not performing wisdom — thinking out loud with receipts.

## Social vs long-form split
- Instagram/social: plain language, "ship" and "build" OK, drop PM jargon
- Website/essays: PM terminology OK, reader self-selected
- Unstuck is a "build partnership practice" — NEVER call it coaching

## Content pillar rules
- Mirror: stops at Agitate. No solution language. CTA = share trigger.
- Machine: how-to, frameworks. CTA = save or DM keyword.
- Proof: case studies, results. CTA = DM keyword.

## Instagram format mix (growth phase 0-5K):
- 40% Reels, 35% carousels, 25% statics, 5-6 posts/week
- 1 personal/BTS post per week minimum (high-ticket requires it)
- Calendar before content — plan the full month, then produce

## Meme rules:
- 70+ templates, no repeat within 2 weeks
- Caption: 1-3 lines max, don't explain the joke
- "Tag someone" or "save this" — keep it casual

## Copy is sacred — never rewrite to fix layout

When QA detects overflow or word breaks in a Canva carousel or HTML slide, **adjust the template, not the copy.**

1. First try: reduce font size (`format_text` with smaller `font_size`)
2. Second try: widen the container (`resize_element` with larger `width`)
3. Last resort: pick a different template with wider headline containers
4. **NEVER:** rewrite the headline to use shorter words

Rewriting headlines to fit a template dilutes the message. The template serves the content, not the other way around. Auto-fix uses `format_text` and `resize_element`, never `replace_text`.

## Carousel variety — vary structural axes, not just palettes

Batching all carousels in the same template fails Molly's variety bar twice over:
- First batch: same Gold Indigo template across 22 carousels → "you have failed me again"
- Second batch: varied palettes but same structural layout → "starting to look like we aren't varying the carousel formats"

Each carousel: pick format from `carousel-formats.md`, palette from `instagram-palettes.md`, **vary 2+ structural axes** (layout, slide count, hierarchy, accent placement).

Render 1 sample slide → get approval → THEN complete the set. One-at-a-time with approval gates lets Molly catch issues early (CTA logic, AI tells, color contrast) before they propagate across 9-22 outputs.

## Source copy only when restyling

When restyling existing slides, **read source HTML first and preserve copy verbatim.** Inventing new copy on supposedly-restyled slides produces AI tells (caught on archetype slides 1+6, session 2026-04-07).

## Off-screen detection

Always QA every page after Canva edits. Canva auto-corrects some text containers but not all.
- Off-screen check: `left + width > 1080` or `top + height > 1350`

## Banned vocabulary (cross-ref content-voice.md)

unlock, unleash, manifest, journey, transformation, level up, game-changer, revolutionary, synergy, holistic, paradigm shift, deep dive (as verb), lean in, circle back, move the needle, at the end of the day. Number "47" never appears as an "arbitrary" example.

## Enforcement
- CARL WRITING domain (7 rules)
- CARL CONTENT-RULES domain (8 rules)
- content-qa-guarded.sh PostToolUse hook
- Caption pipeline: unstuck/prompts/caption-generator.md

## Cross-refs
- `verify-before-commit.md` — read agent-written copy, grep for AI tells
- Content-system memory: `feedback_never_change_copy_for_layout.md`, `feedback_session_canva_carousel.md`, `feedback_session_v2_variety_rebuild.md`
