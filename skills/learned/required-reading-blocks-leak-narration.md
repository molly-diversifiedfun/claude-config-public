---
name: required-reading-blocks-leak-narration
description: "Any `<required_reading>` block in a Claude.ai skill leaks tool-call narration to the buyer via Claude.ai's collapsible \"Viewed N files\" UI. Strip them all. Move required context into plain instruction prose inside SKILL.md or methodology docs."
type: learned-pattern
applies-to: [all-claude-ai-skills, voice, narration, skill-architecture]
projects: [all]
severity: blocking
phase: [build, voice, deploy]
last-validated: 2026-05-19
archetypes: [always-on]
---

# Pattern: `<required_reading>` blocks leak narration in Claude.ai UI

## Rule

`<required_reading>` blocks inside Claude.ai skill commands (T-templates, methodology commands, etc.) trigger the Claude.ai UI to render "Viewed N files" collapsible sections that the buyer sees. This reads as the AI narrating its tool calls — the exact voice failure the no-narrate reflex was supposed to kill. **Strip them all.**

## Why

In the 2026-05-19 voice-tighten ship, even after adding the no-narrate reflex check ("delete sentence if first token is Let me / I'll / Now / First / Read"), buyers still saw narration. Investigation: it wasn't text the model generated — it was Claude.ai's UI auto-rendering `<required_reading>` block file lists as a "Viewed N files" expandable section. Mass-stripping the block from 41 commands (24 T-templates + 16 Kit methodology + 1 momentum) eliminated the leak entirely.

## How to apply

When building or auditing any Claude.ai skill:

1. `grep -r "<required_reading>" claude-skills/ <your-product-pipeline>/skills/` should return **zero hits**.
2. If a command needs to reference required context, put it as plain instruction prose in SKILL.md or in the command's body — not in a structured block Claude.ai's UI knows how to render.
3. Add this to the no-narrate enforcement checklist in `00-master-system-prompt.md`.

## Origin

2026-05-19 ABP buyer-signals ship — voice-tighten phase. Cross-refs: [[voice-and-content-rules]] (Kerouac × Sinek × Sanchez voice formula), [[ai-tell-avoidance]] (same AI-tell category).
