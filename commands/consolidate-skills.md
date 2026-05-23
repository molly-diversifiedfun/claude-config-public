---
description: Scan installed skills for consolidation candidates. Composite score (description Jaccard + bake-off losses + Phase 7.4 elim). Tiered HIGH/MEDIUM/LOW markdown report. Read-only.
---

# /consolidate-skills — skill catalog consolidator (Phase 7.7a)

Run the Python analyzer over all installed skills (`~/.claude/skills/` + `~/.claude/plugins/cache/**/skills/`):

```bash
if [ "${SKILL_CONSOLIDATE:-on}" = "off" ]; then
  echo "/consolidate-skills disabled (SKILL_CONSOLIDATE=off)"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 required — install via Homebrew or system."
  exit 0
fi
python3 "$HOME/.claude/scripts/consolidate-skills.py"
```

After the report path prints, open the file:
- **HIGH tier** — strong consolidation candidates with actionable verbs. Highest priority.
- **MEDIUM tier** — review-worthy, lower confidence.
- **LOW tier** — informational only (includes all plugin+plugin pairs).

Reports accumulate at `~/.claude/data/skill-consolidation-reports/` — one MD file per run.

Read-only. No auto-apply. User runs `rm` manually for any approved consolidations.
