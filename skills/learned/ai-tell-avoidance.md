---
name: ai-tell-avoidance
description: Senior tech audience clocks AI content instantly. Three categories of AI tells (47, Notion-only refs, vocab clusters) that pass tools but fail human readers. Two-pass detection via humanize-ai-writing.
type: learned-pattern
applies-to: [content, verification]
projects: [all]
severity: blocking
phase: [content, verify, capture]
last-validated: 2026-05-12
archetypes: [brand-content, always-on]
---

# Pattern: AI-Tell Avoidance

Senior tech audience clocks AI content instantly. Three categories of tells caught in production:

## 1. Number tells
- NEVER use 47 (appeared 11 times across April/May content)
- Vary all numbers: 14, 19, 23, 28, 31, 33, 38, 42
- No round numbers. No repeats across pieces.

## 2. Reference tells
- Don't default to Notion for every tech reference
- Rotate: Figma, Vercel, Railway, Supabase, Cursor, VS Code, Stripe, Linear, GitHub, Airtable, Framer
- Match the tool to the context of the joke

## 3. Structural tells
- Kill: "I'd be happy to", "Great question", delve, leverage, utilize, robust, comprehensive, pivotal, seamless
- Kill copula avoidance: "serves as" → "is", "features" → "has"
- Kill significance inflation: "marking a pivotal moment" → just state the fact
- Kill present participial endings: "...highlighting the need for..."
- Kill balanced-perspective reflex: state a position, don't false-balance

## Enforcement
- CARL WRITING_RULE_2, WRITING_RULE_3, WRITING_RULE_4
- CARL CONTENT-RULES_RULE_0 (AI-tell sweep before delivery)
- content-qa.sh PostToolUse hook (tool mentions, PM jargon)
- Three-pass system in humanize-ai-writing: Pass-0 annotated report (interactive mode) → Pass-1 audit-and-rewrite → Pass-2 residual audit
