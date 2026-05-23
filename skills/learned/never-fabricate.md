---
name: never-fabricate
description: NEVER invent personal stories, numbers, metrics, or facts. Source claims from real evidence.
type: learned-pattern
applies-to: [content, verification]
projects: [all]
severity: blocking
phase: [define, explore, build, review, deploy, capture]
trigger: [stat-without-source, story-without-evidence, made-up-metric]
last-validated: 2026-05-10
archetypes: [always-on]
---

# Pattern: Never Fabricate Personal Details

A previous session invented "$2,400 PDF on Gumroad" and propagated it across 20 files. Real story: $21 PDF, 3 sales.

## What's confirmed real:
- <your unlaunched-thing example> Shopify store, 4 years, $1,392 in fees, never launched
- $21 PDF on Gumroad, 4-module fillable worksheets, 3 sales from strangers
- BurnFriends: first big ship, 200 users in 6 weeks
- GiftShopper: your OWN project (not a client), shipped in 6 weeks
- Senior Director at Heap/Contentsquare, promoted 2026, 20+ years in tech
- Career: Google → SoftBank → Neustar → Andela → Heap → Contentsquare
- $5M migration recovery + $2M annual savings (Heap story specifically)
- <your signature project> for <your specific public stories>

## What's confirmed fabricated (never use):
- "Planned a video course for a year" — never happened
- "Recorded a podcast, 2 episodes" — never happened
- "Made a 47-slide course" — never happened
- "Mom bought it with two email addresses" — her mom is dead
- GiftShopper framed as a "client" story — it's your project

## Rule
When writing content referencing your experiences, ASK for real details. Small real numbers ($21 PDF, 3 sales) > fake impressive ones.

## Sub-rule: Case studies are NEVER fabricated

Module 0 invented 3 fake personas as "case studies." This is a blocking violation. When a deliverable calls for a case study and no real one exists, use one of:
- `*[Case Study: to source — needs your input]*` placeholder
- Real you ships (Bio.tsx is the source of truth — GiftShopper, BurnFriends, $21 PDF)
- Public-documented stories (cite source + URL)

Never invent a customer, a result, or a number. "Sarah, a designer who...." is fabrication even if the story is plausible.

## Sub-rule: Vaporware references are a grep-detectable class of bug

Before publishing copy that names artifacts (modules, templates, scripts, PDFs, webhooks), confirm the artifact exists at the URL/path you're citing. Advertise > deliver gaps compound across surfaces — one fabricated reference in welcome.md propagates into the LP, the JSON-LD, the LLM brief, the Notion template.

The class of bug: copy describes a future state ("includes the Reframe Generator module") while the artifact doesn't exist yet. Grep all surfaces for the named artifact. If grep returns only marketing copy, it's vaporware — either build it or strip the reference.

## Sub-rule: Demo walkthroughs require explicit labels

Labels are load-bearing. A demo/example/simulation walkthrough is only OK if labeled "Example", "Demo", or "Simulated" inline. Unlabeled walkthroughs read as real customer stories — and you will treat them as fabrication. When in doubt, label.

## Enforcement
- CARL GLOBAL_RULE_6 (always on)
- CARL CONTENT-RULES_RULE_1
- CARL WRITING_RULE_5
- feedback_never_fabricate_personal_stories.md (full reference)
