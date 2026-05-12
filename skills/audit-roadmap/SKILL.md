---
name: audit-roadmap
description: Verify roadmap "done" stories against actual code. Reads the story map, greps codebase to verify each [x] and [~] claim. Categorizes as VERIFIED/PARTIAL/FAKE. Use when checking roadmap accuracy, before demos, or after build sessions. Trigger on "audit roadmap", "verify stories", "what's actually done", "roadmap accuracy".
---

# Audit Roadmap

Verify that roadmap story completion claims match actual code. Read-only — never modifies files.

## Process

### 1. Load Stories
Read `docs/designs/roadmap-v3-complete-story-map.md`. Extract all `[x]` (done) and `[~]` (partial) stories.

### 2. Verify Each Story

For each story, determine what code artifact proves it works:

| Story type | What to check |
|---|---|
| Integration ("Connect X") | OAuth service + edge function + UI component + DB table |
| UI feature ("Dashboard shows X") | Component file + page route + service/hook |
| Data ("Calculate X") | Service function + edge function + DB view |
| Export ("PDF", "CSV", "Email") | Export service + edge function + UI trigger |
| Infrastructure ("RBAC", "RLS") | Guard components + migrations + shared utils |

**Use these tools (read-only):**
- Glob — find files by name pattern
- Grep — search for function names, imports, routes
- Read — inspect files for TODOs, mock data, stubs

**Red flags that downgrade to PARTIAL:**
- `TODO`, `FIXME`, `// not implemented`
- Returns mock/demo data only
- Commented-out code
- No tests
- Broken dependency (import from missing file)

**Red flags that downgrade to FAKE:**
- No component, service, or edge function found
- File exists but is empty/placeholder
- Only exists in mockData.ts

### 3. Categorize

| Category | Criteria |
|---|---|
| **VERIFIED** | Code exists, appears functional, no obvious gaps |
| **PARTIAL** | Code exists but has known gaps (TODOs, mock-only, incomplete) |
| **FAKE** | Marked done but no code supports the claim |

### 4. Output Report

```markdown
# Roadmap Audit Report — YYYY-MM-DD

## Summary
| Category | Count |
|----------|-------|
| Verified | X |
| Partial  | Y |
| Fake     | Z |
| **Total** | **N** |

Accuracy: X/N (XX%)

## Partial — Needs Attention
| Story | Gap |
|-------|-----|
| ... | ... |

## Fake — Not Built
| Story | Evidence |
|-------|----------|
| ... | ... |
```

### 5. Scope Control

- Audit `[x]` and `[~]` stories only (skip `[ ]`)
- User can scope: "audit Sense phase only", "audit outcome 1"
- DO NOT modify files, run tests, deploy, or commit
- If 50+ stories, batch by outcome and show progress
