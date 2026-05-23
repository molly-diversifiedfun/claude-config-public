---
description: Classify the first real user prompt of recent sessions through Stage 0 (ship-scope-classify.py). Markdown table of scope vs actual outcome — useful for validating classifier calibration after prompt changes.
---

# /ship-scope-replay — classifier calibration tool

Walks recent session transcripts, extracts the first real user prompt (skipping auto-summary / hook-feedback / caveat noise), and runs each through the Stage 0 scope classifier. Outputs a markdown table comparing prescribed scope to actual outcome metadata (duration, tool count, Skill invocations).

Default N=30. Override with `SHIP_SCOPE_REPLAY_N=<n>` or pass as positional arg.

```bash
if [ "${SHIP_SCOPE_REPLAY:-on}" = "off" ]; then
  echo "/ship-scope-replay disabled (SHIP_SCOPE_REPLAY=off)"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 required."
  exit 0
fi
python3 "$HOME/.claude/scripts/ship-scope-replay.py" "$@"
```

Use when:
- You changed the Stage 0 prompt template and want to verify regressions across real asks
- You added a new heuristic (e.g. continuation rule, scope inheritance) and want to see which historical sessions it reclassifies
- You're investigating "is the classifier under-tiering or over-tiering my work?"

Reports accumulate at `~/.claude/data/scope-replay-reports/<ISO>.md`.

**Cost:** ~$0.005 per classified session via `claude --bare` Haiku 4.5. At N=30 ≈ $0.15 + ~30s wall time (6 parallel workers).

**Kill switch:** `SHIP_SCOPE_REPLAY=off`.
