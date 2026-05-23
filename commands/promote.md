Promote a project-local feedback memory file into a cross-project learned pattern.

Usage: `/promote [feedback_xxx.md]`

- With a filename: process that specific feedback file (basename match across the 7 known memory dirs).
- No args: scan all 7 memory dirs for feedback files newer than the newest `learned/` file (same "synthesis candidate" definition `synthesize-learnings.sh` uses), present the list, ask which to promote.

## Pre-flight

1. **MemPalace status check** — call `mcp__mempalace__mempalace_status`. If unhealthy, raise BLOCKED. Do NOT fall back to file Glob on memory dirs — that re-introduces stale on-disk content as authoritative (per Phase 4 rule).
2. **Resolve target file:**
   - If arg provided → search the 7 memory dirs from `synthesize-learnings.sh` for a file matching the basename. Read the first match. If multiple, list them and ask which.
   - If no arg → scan the 7 dirs for `feedback_*.md` newer than the newest `~/.claude/skills/learned/*.md` (excluding `SKILL.md`). Use `AskUserQuestion` to let you pick one.
3. **Read the feedback file end-to-end.** Note the `applies-to:` tags, the rule, the why, and any `[[cross-refs]]`.

## Workflow

### Step 1 — Gather neighbors

Two independent searches, run in parallel:

a) **MemPalace semantic neighbors** — `mcp__mempalace__mempalace_search` with the feedback's rule sentence as query. NO wing filter (we want cross-project matches). Wing-filter fail-open per `mempalace-discipline.md` § wing-filter — if any sub-query uses a wing filter and errors with `Error finding id`, retry without it. Capture top 5-10 hits.

b) **Existing learned/ candidates** — Glob `~/.claude/skills/learned/*.md` and Read the SKILL.md index. Pick the 3 patterns whose `applies-to:` tags overlap most with the feedback's tags (or whose topic is semantically closest from the index table).

### Step 2 — Propose options

Present 3 options via `AskUserQuestion`:

- **Option A (recommended when overlap is strong):** Extend `learned/<best-match>.md` with a new `## <section>` block. Show the proposed section header + 2-3 line summary.
- **Option B:** Create new `learned/<topic-slug>.md` with v2 frontmatter (per `~/.claude/CLAUDE.md` — fields: `name`, `description`, `type`, `applies-to`, `projects`, `severity`, `phase`, `last-validated`). Use the feedback file's existing tags as the seed.
- **Option C:** Leave project-local. The topic isn't cross-project enough, OR the feedback duplicates an existing pattern verbatim. No file change.

For each option, list:
- What changes (target file path + lines added)
- What stays the same (feedback file remains untouched as the archaeological source)
- Cross-refs to add (`[[name]]` links in target pattern)

If MemPalace surfaced ≥2 semantically similar drawers from OTHER projects, call that out — it's positive evidence the pattern is cross-project, supporting Option A or B over C.

### Step 3 — Apply the picked change

- **A (extend):** Backup the target file to `~/github/.ship/<date>-promote-<feedback-slug>/backup/`. Append the new section. Update `last-validated:` in frontmatter. Add a row to the source feedback file at the bottom: `> Promoted to learned/<target>.md § <section> on YYYY-MM-DD`.
- **B (create):** Write the new `learned/<slug>.md`. Add a row to `~/.claude/skills/learned/SKILL.md` § Pattern index. Bump the count in the SKILL.md description ("24 patterns" → "25 patterns"). Append a `## Last synthesis` entry to SKILL.md noting the new pattern.
- **C (skip):** No file change. Output one sentence explaining why kept project-local.

### Step 4 — Report

- Print the affected files (`learned/<target>.md`, `SKILL.md`, and the source feedback file).
- Print a 1-line git-status preview (e.g. `M skills/learned/<target>.md`, `M skills/learned/SKILL.md`).
- Remind you to commit: do NOT auto-commit. Synthesis decisions deserve manual review. Use `/commit-push-pr` or stage manually.

## Guardrails

- Never auto-promote. The `AskUserQuestion` step is mandatory; even when Option A is obvious, the prompt must wait for your pick.
- Never touch project memory dirs other than the source feedback file. Per-project memory is WRITE-ONLY post-Phase 4 except for capture; this command's writes land only in `~/.claude/skills/learned/` and (optionally) a one-line "promoted to..." footer on the source feedback file.
- Never overwrite an existing `learned/<slug>.md` when creating new. If the slug collides, switch to Option A (extend) instead.
- Backup before any edit to an existing `learned/` file.
- If MemPalace is unhealthy at pre-flight, BLOCKED. Do not promote without cross-project signal.

## Why this workflow

Promotion from project-local feedback → cross-project learned/ pattern is pure judgment work. The synthesis history in `learned/SKILL.md` shows 5-10 patterns get added per major synthesis batch — easy to over-promote (bloating learned/ with noise) or under-promote (losing the cross-project signal). The 3-option proposal forces the judgment call to be explicit, and the MemPalace neighbor scan provides the data you needs to decide.

The command does NOT enforce a cadence — that's Phase 6.1's job (Stop-hook synthesis enforcement). `/promote` is the tool you reach for once you've decided to synthesize.

## Examples

`/promote feedback_palace_file_lock_under_concurrent_miner_load.md`
→ Expects Option A: extend `learned/mempalace-discipline.md` § palace file lock under concurrent load.

`/promote feedback_bash_var_plus_default_nonempty_gotcha.md`
→ Expects Option B (new) OR a paired Option B with `feedback_bash_dollar_question_capture_order.md` as a single new `learned/bash-discipline.md`. Surfacing pair-candidates is a Phase 6.3 extension; today this command processes one feedback at a time.

`/promote`
→ Scans the 7 memory dirs, lists synthesis candidates (feedback files newer than newest `learned/` file), asks which to promote.

## Cross-refs

- `~/.claude/projects/<your-workspace>/memory/project_mempalace_phase6_meta_learning_propagation.md` § 6.4 — origin spec
- `~/.claude/skills/learned/mempalace-discipline.md` § wing-filter fail-open — MemPalace query discipline
- `~/.claude/skills/learned/SKILL.md` — the index this command updates
- `~/.claude/hooks/synthesize-learnings.sh` — the SessionStart gap flagger this command resolves
- `~/.claude/CLAUDE.md` § Memory System — v2 frontmatter schema for new learned/ files
