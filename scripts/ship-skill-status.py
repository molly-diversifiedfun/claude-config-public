#!/usr/bin/env python3
"""Phase 8.1 (advisory) — /ship skill-binding status.

Reads `.ship/<run>/scope.json` + skills-invoked.log and reports which
expected superpowers skills (per the scope→stage matrix in commands/ship.md)
have fired this run vs which haven't. Advisory output — never blocks.

Use during a /ship run to see what discipline you've already invoked and
what's still expected. Pair with /system-retro to measure whether
following the bindings correlates with better per-mode scores.

Kill switch: SHIP_SKILL_STATUS=off
Env-var overrides (testing):
  SHIP_SKILL_STATUS_RUN_DIR  override `.ship/<run>/` lookup
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

# Scope → expected superpowers skills (mirrors commands/ship.md matrix).
# Tracks the discipline gates that empirically tend to matter at each scope.
EXPECTED_BY_SCOPE: dict[str, list[str]] = {
    "S": [
        "superpowers:test-driven-development",
        "superpowers:verification-before-completion",
    ],
    "M": [
        "superpowers:brainstorming",
        "superpowers:test-driven-development",
        "superpowers:verification-before-completion",
        "superpowers:requesting-code-review",
        "superpowers:finishing-a-development-branch",
    ],
    "L": [
        "superpowers:brainstorming",
        "superpowers:writing-plans",
        "superpowers:test-driven-development",
        "superpowers:subagent-driven-development",
        "superpowers:verification-before-completion",
        "superpowers:requesting-code-review",
        "superpowers:finishing-a-development-branch",
    ],
    "XL": [
        "superpowers:brainstorming",
        "superpowers:writing-plans",
        "superpowers:test-driven-development",
        "superpowers:subagent-driven-development",
        "superpowers:verification-before-completion",
        "superpowers:requesting-code-review",
        "superpowers:finishing-a-development-branch",
    ],
}


def kill_switch() -> bool:
    return os.environ.get("SHIP_SKILL_STATUS", "on").lower() == "off"


def find_run_dir() -> Path | None:
    """Locate the active .ship/<run>/ via env override or most-recent scope.json."""
    env = os.environ.get("SHIP_SKILL_STATUS_RUN_DIR")
    if env:
        p = Path(env)
        return p if p.is_dir() else None
    ship = Path.cwd() / ".ship"
    if not ship.is_dir():
        return None
    runs = [d for d in ship.iterdir() if d.is_dir() and (d / "scope.json").exists()]
    if not runs:
        return None
    return max(runs, key=lambda d: (d / "scope.json").stat().st_mtime)


def read_scope(run_dir: Path) -> str | None:
    try:
        data = json.loads((run_dir / "scope.json").read_text())
        scope = data.get("scope")
        return scope if scope in EXPECTED_BY_SCOPE else None
    except (OSError, json.JSONDecodeError):
        return None


def read_invocations(run_dir: Path) -> list[dict]:
    log = run_dir / "skills-invoked.log"
    if not log.exists():
        return []
    out: list[dict] = []
    try:
        for line in log.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(rec, dict) and rec.get("skill"):
                out.append(rec)
    except OSError:
        pass
    return out


def render_status(run_dir: Path, scope: str, invocations: list[dict]) -> str:
    expected = EXPECTED_BY_SCOPE[scope]
    invoked_set = {inv["skill"] for inv in invocations}
    lines = [
        f"# /ship skill-binding status",
        "",
        f"**Run:** `{run_dir.name}`  •  **Scope:** {scope}  •  "
        f"**Invocations logged:** {len(invocations)}  •  "
        f"**Expected skills:** {len(expected)}",
        "",
        "## Expected vs fired",
        "",
        "| Expected skill | Fired? |",
        "|---|---|",
    ]
    for skill in expected:
        mark = "✅" if skill in invoked_set else "⏳ pending"
        lines.append(f"| `{skill}` | {mark} |")

    extras = invoked_set - set(expected)
    if extras:
        lines.append("")
        lines.append("## Extra skills invoked (not in expected set for this scope)")
        lines.append("")
        for sk in sorted(extras):
            lines.append(f"- `{sk}`")

    missing = [s for s in expected if s not in invoked_set]
    lines.append("")
    if missing:
        lines.append(
            f"⚠️ Advisory: {len(missing)}/{len(expected)} expected skill(s) not yet "
            f"invoked. This is informational only — Phase 8.1 is advisory, never blocks. "
            f"Use /system-retro to see if following the bindings correlates with better "
            f"per-mode outcomes."
        )
    else:
        lines.append(f"✅ All {len(expected)} expected skills for scope={scope} have fired.")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if kill_switch():
        print("/ship-skill-status disabled (SHIP_SKILL_STATUS=off)")
        return 0

    run_dir = find_run_dir()
    if run_dir is None:
        print("_No active /ship run found in cwd (`.ship/<run>/scope.json` missing)._")
        return 0

    scope = read_scope(run_dir)
    if scope is None:
        print(f"_Found `{run_dir}` but scope.json is missing or invalid._")
        return 0

    invocations = read_invocations(run_dir)
    print(render_status(run_dir, scope, invocations))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
