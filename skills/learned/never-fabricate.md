---
name: never-fabricate
description: NEVER invent personal stories, numbers, metrics, or facts. Source claims from real evidence.
type: learned-pattern
applies-to: [content, verification]
projects: [all]
severity: blocking
phase: [define, explore, build, review, deploy, capture]
trigger: [stat-without-source, story-without-evidence, made-up-metric]
last-validated: 2026-05-12
---

# Pattern: Never Fabricate Personal Details

A previous session invented a story about a $2,400 product launch and propagated it across 20 files. The real story was a $21 product with 3 sales. The fabricated version was more flattering and would have been catastrophic if shipped publicly.

This is one of the most common failure modes when an LLM is writing in someone's voice: it will invent plausible-sounding numbers, projects, milestones, and revenue figures that sound impressive. None of them are real.

## The rule

**When writing content referencing your experiences, ASK for real details before writing.** Small real numbers ($21 PDF, 3 sales) > fake impressive ones ($2,400 PDF, 47 sales). The audience can smell fabrication; the LLM cannot.

## How to apply

Maintain a "confirmed real" / "confirmed fabricated" list in your private memory directory (an example template is shown below — fill in with your own data). Reference it before any content generation that involves personal narrative.

### Template — confirmed real (replace with your own)

```
- <your launched product>, <real metric>
- <your unlaunched product>, <real cost / time>
- <your day job title / company / years>
- <your career arc>
- <your signature shipped project + outcome>
```

### Template — confirmed fabricated (never use)

```
- <stories the LLM has invented in past sessions that sounded plausible but aren't real>
- <metrics that were inflated>
- <relationships or events that never happened>
```

The original config tracked specific items in the workspace memory's `feedback_never_fabricate_personal_stories.md` file. That file isn't in this public snapshot but the pattern is the same: maintain the lists, reference them on every content task.

## Enforcement

- CARL GLOBAL_RULE_6 (always on) — single most-important rule across all content work
- CARL CONTENT-RULES_RULE_1
- CARL WRITING_RULE_5
- Reference the per-workspace `feedback_never_fabricate_personal_stories.md` (or your equivalent) for the canonical real-story list
