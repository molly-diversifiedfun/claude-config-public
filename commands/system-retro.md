---
description: One-shot retrospective over the last 20 Claude Code sessions. Per-mode aggregates, exemplars, anti-exemplars, cross-cutting themes via Haiku judge.
---

# /system-retro — process retrospective across recent sessions

Walks `~/.claude/projects/*/*.jsonl`, takes the last N real session transcripts (excludes subagent dispatches + zero-byte files), joins git commits + hook blocks + agent-eval judgments per session window, and runs a Haiku 4.5 judge on four dimensions: **shipped+smoked**, **incremental value**, **mode-fit**, **time-to-done vs scope**. A synthesis judge surfaces cross-cutting themes.

Default N=20. Override with `SYSTEM_RETRO_N=<n>`.

```bash
if [ "${SYSTEM_RETRO:-on}" = "off" ]; then
  echo "/system-retro disabled (SYSTEM_RETRO=off)"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 required."
  exit 0
fi
python3 "$HOME/.claude/scripts/system-retro.py"
```

After the path prints, open the report:
- **Per-mode aggregates** — averages on each of the 4 dimensions, by dominant mode (`ship`, `build`, `fix`, `superpowers`, `raw`, etc.)
- **Process patterns** — counts of `shipped-clean`, `shipped-no-smoke`, `shipped-scope-creep`, `stuck-mid-impl`, etc.
- **Exemplars / Anti-exemplars** — top-3 / bottom-3 sessions by combined score
- **Cross-cutting themes** — synthesis judge over all per-session gap observations
- **Raw session table** — every session with mode, duration, tool/subagent counts, commits, hook blocks

Read-only. No auto-action. Reports accumulate at `~/.claude/data/system-retro/<ISO>.md`.

For an extraction-only dry run (no Haiku tokens):

```bash
SYSTEM_RETRO_NO_JUDGE=1 python3 "$HOME/.claude/scripts/system-retro.py"
```

**Cost:** ~20 Haiku calls via `--bare` + 1 synthesis call. Trivial (~$0.10 per run at default N=20).

**Kill switch:** `SYSTEM_RETRO=off`.
