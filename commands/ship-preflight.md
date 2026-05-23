---
description: Probe external dependencies (CLI commands, env vars, files, URLs) before /ship commits to running. Addresses /system-retro "Prerequisite Validation Skipped" gap.
---

# /ship-preflight — external dependency check

Probes the deps you'll need before /ship commits. Catches "Notion API not configured", "gh CLI missing", "API token expired", "network unreachable" failures BEFORE they sink the session.

## How it works

You (or /ship Stage 1) declares deps in `.ship/<run>/preflight-deps.txt`, one per line:

```
cmd:gh
cmd:railway
env:GITHUB_TOKEN
env:ANTHROPIC_API_KEY
file:~/.config/supabase/config.toml
url:https://api.github.com
```

Then run:

```bash
if [ "${SHIP_PREFLIGHT:-on}" = "off" ]; then
  echo "/ship-preflight disabled (SHIP_PREFLIGHT=off)"
  exit 0
fi
python3 "$HOME/.claude/scripts/ship-preflight.py" "$@"
```

Output: markdown report to stdout + machine-readable `.ship/<run>/preflight.json`. Exits 0 even when probes fail — preflight is a warning gate, not a block. Orchestrator decides whether to continue.

## Probe types

- `cmd:<name>` — `command -v <name>` is available
- `env:<NAME>` — env var is set + non-empty
- `file:<path>` — file exists + readable (supports `~/` expansion)
- `url:<url>` — HEAD request returns 2xx/3xx (5s timeout)

## When to use

- /ship Stage 1 pre-flight (orchestrator declares deps based on the ask)
- Before any session that depends on external tools / APIs / files
- To verify deploy credentials are present before pushing

**Kill switch:** `SHIP_PREFLIGHT=off`.
