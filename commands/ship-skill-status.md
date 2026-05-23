---
description: Report which superpowers skills have fired in the current /ship run vs which are expected per the scope. Advisory only — never blocks. Phase 8.1 observability layer.
---

# /ship-skill-status — fired vs expected skill bindings

Reads `.ship/<run>/scope.json` + `skills-invoked.log` (populated by the `ship-skill-tracker.sh` PostToolUse:Skill hook) and shows which superpowers skills have fired this run versus which are expected per the scope→stage matrix in `commands/ship.md`.

```bash
if [ "${SHIP_SKILL_STATUS:-on}" = "off" ]; then
  echo "/ship-skill-status disabled (SHIP_SKILL_STATUS=off)"
  exit 0
fi
python3 "$HOME/.claude/scripts/ship-skill-status.py"
```

**Phase 8.1 is advisory only — never blocks.** The N=28 dogfood (2026-05-23) showed superpowers scored worst on shipping (2.7), so forcing more superpowers invocations might hurt /ship. This layer logs invocations + reports gaps, then /system-retro can later measure whether following the bindings correlates with better per-mode outcomes. Enforcement only if data eventually justifies it.

**Expected skills per scope** (see `commands/ship.md` § Stage → superpowers binding):

- **S**: `tdd`, `verification-before-completion`
- **M**: + `brainstorming`, `requesting-code-review`, `finishing-a-development-branch`
- **L**: + `writing-plans`, `subagent-driven-development`
- **XL**: (same as L)

**Kill switch:** `SHIP_SKILL_STATUS=off`.
