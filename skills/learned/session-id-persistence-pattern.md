---
name: session-id-persistence-pattern
description: "Never use `$$` (shell PID) for session_id in Claude.ai skill telemetry. Claude.ai spawns a fresh `bash -c` per tool call → every event gets a new session_id → all funnels collapse. Persist to `~/.<skill>/current_session_id` with a sliding TTL (30 min idle = new session) and stamp `current_session_at` on every fire."
type: learned-pattern
applies-to: [telemetry, claude-ai-skills, posthog, session-tracking, infrastructure]
projects: [all]
severity: warning
phase: [build, infra]
last-validated: 2026-05-20
archetypes: [telegram-bot, content-pipeline]
---

# Pattern: Session ID persistence for Claude.ai skill telemetry

## Rule

Claude.ai spawns a fresh `bash -c` process for every tool-call (it does NOT keep one shell alive across model turns). That means `$$` (Bash PID) is different on every event. Any session_id keyed on `$$` (e.g. `/tmp/abp-session-$$`) breaks: every event in a single Claude.ai conversation gets a different session_id, and Activation/Value/Shipping funnels all collapse because no events join.

## The fix

Persist session_id to a file at a known path with a sliding TTL.

```bash
ABP_DIR="$HOME/.ai-build-partner"
NOW=$(date +%s)
LAST=$(cat "$ABP_DIR/current_session_at" 2>/dev/null || echo 0)
SID_FILE="$ABP_DIR/current_session_id"
if [[ -s "$SID_FILE" && $((NOW - LAST)) -lt 1800 ]]; then
  SID=$(cat "$SID_FILE")
else
  SID=$(uuidgen)
  echo "$SID" > "$SID_FILE"
fi
echo "$NOW" > "$ABP_DIR/current_session_at"   # sliding window — every fire bumps it
```

## Why

Sanity test on 2026-05-19 confirmed two separate `bash -c` invocations 500ms apart returned the SAME UUID with this pattern; with `/tmp/abp-session-$$` they would have been different UUIDs. Funnels need a consistent session_id across N events, and Claude.ai gives no env var or hook to expose its actual conversation ID.

## How to apply

1. Any per-conversation key in a Claude.ai skill (session_id, dedup marks, ephemeral state) goes in `~/.<skill>/` with a TTL stamp, never in `/tmp/$$`.
2. Apply the same fix to dedup files — `save_block_fired` dedup moved from `/tmp/abp-save-$$-<cmd>` to `~/.ai-build-partner/save-marks/<cmd>` so dedup actually works cross-shell.
3. 30-min idle TTL is a starting guess; observe and tune based on real session-length distributions.

## Origin

2026-05-19 ABP buyer-signals ship — reviewer-caught telemetry bug. Cross-refs: [[mempalace-discipline]] (where the telemetry lives), [[verify-before-commit]].
