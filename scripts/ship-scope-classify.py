#!/usr/bin/env python3
"""Phase 8.0 — /ship scope classifier.

Takes a feature description from argv or stdin, asks Haiku 4.5 to bucket it
into S / M / L / XL, returns JSON to stdout. The /ship command reads this
to pick which stages to run (small fix = lean pipeline; arch change = full).

Scope tiers:
  S  — single-file fix, typo, config tweak, dep bump.       (Stages: 6+9)
  M  — feature, refactor with tests, new endpoint.          (Stages: 1+2+3+6+7+9+10+11)
  L  — multi-component feature, migration, UI overhaul.     (Stages: 1+2+3+4*+5*+6+7+8+9+10+11)
  XL — architectural change, new service, breaking redesign.(All stages + ADR + double memory pass)

Read-only. Soft-fails to S (smallest safe default) on Haiku failure.

Kill switch: SHIP_SCOPE=off → always returns {"scope":"M","rationale":"classifier disabled"}.
Env-var overrides (testing):
  SHIP_SCOPE_CLAUDE_CMD  override `claude` binary path
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

JUDGE_MODEL = "claude-haiku-4-5-20251001"
JUDGE_TIMEOUT_S = 30
INHERIT_MAX_AGE_DAYS = 7  # scope.json older than this is treated as stale

SYSTEM_PROMPT = (
    "You classify software-engineering tasks into one of 4 scope tiers: "
    "S (single-file fix/typo/config), M (feature with tests, refactor, new endpoint), "
    "L (multi-component feature, migration, UI overhaul), "
    "XL (architectural change, new service, breaking redesign). "
    "Your ENTIRE response must be a single JSON object. Start with '{' and end with '}'. "
    "No prose, no fences."
)

PROMPT_TEMPLATE = """Classify this ask into one scope tier:

ASK:
{ask}

Tiers (pick the smallest that fits — err toward S for self-contained asks):
- S  — single-file fix, typo, config tweak, dep bump, comment update
- M  — feature with tests (1-3 files), refactor, new endpoint, schema column add
- L  — multi-component feature, migration, UI overhaul, multi-file refactor
- XL — architectural change, new service, breaking redesign, framework swap

CONTINUATION RULE: If the ask references prior work without giving its own
scope ("step N", "do the next part", "continue from before", "lets do X" where
X is a phase/step name, "finish what we started"), DEFAULT TO M (not S) and
note that scope likely inherits from the parent work. The orchestrator can
override via .ship/<run>/scope.json. Vague short prompts on big sequences
historically misclassified as S.

Respond with ONLY this JSON object:
{{"scope":"<S|M|L|XL>","rationale":"<one sentence on why>"}}"""


def kill_switch() -> bool:
    return os.environ.get("SHIP_SCOPE", "on").lower() == "off"


def _resolve_claude_cmd() -> str:
    return os.environ.get("SHIP_SCOPE_CLAUDE_CMD") or "claude"


def _strip_fences(s: str) -> str:
    s = s.strip()
    if s.startswith("```"):
        s = re.sub(r"^```[a-zA-Z]*\n", "", s)
        s = re.sub(r"\n```\s*$", "", s)
    return s.strip()


def _extract_json_object(s: str) -> str | None:
    """Find the first {...} JSON object in a string. Handles prose prefix + escapes."""
    start = s.find("{")
    if start < 0:
        return None
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(s)):
        c = s[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return s[start:i + 1]
    return None


def _find_recent_scope_json(search_dir: Path | None = None) -> tuple[Path, dict] | None:
    """Check for an existing recent `.ship/<run>/scope.json` in cwd.

    Returns (path, parsed_json) for the most-recent scope.json modified within
    INHERIT_MAX_AGE_DAYS; None if no fresh scope file exists.

    Continuation prompts ("pick it back up", "lets do step 5 build") tend to
    inherit their parent run's scope. The dogfood replay (2026-05-23, N=28)
    found 3 sessions where this rule would have correctly promoted M → L.

    Test override: SHIP_SCOPE_INHERIT_DIR points at a fake .ship/ parent.
    """
    if search_dir is None:
        env = os.environ.get("SHIP_SCOPE_INHERIT_DIR")
        search_dir = Path(env) if env else Path.cwd()
    ship_dir = search_dir / ".ship"
    if not ship_dir.is_dir():
        return None
    cutoff = time.time() - (INHERIT_MAX_AGE_DAYS * 86400)
    best: tuple[float, Path, dict] | None = None
    for scope_file in ship_dir.glob("*/scope.json"):
        try:
            st = scope_file.stat()
        except OSError:
            continue
        if st.st_mtime < cutoff:
            continue
        try:
            data = json.loads(scope_file.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict) or data.get("scope") not in ("S", "M", "L", "XL"):
            continue
        if best is None or st.st_mtime > best[0]:
            best = (st.st_mtime, scope_file, data)
    return (best[1], best[2]) if best else None


def classify(ask: str) -> dict:
    """Return {scope, rationale}. Soft-fails to S on any Haiku failure.

    Inheritance: if `.ship/<run>/scope.json` exists in cwd and is fresh
    (within INHERIT_MAX_AGE_DAYS), inherit that scope instead of calling
    Haiku. Saves cost and gives continuation prompts the parent's scope.
    """
    if kill_switch():
        return {"scope": "M", "rationale": "classifier disabled (SHIP_SCOPE=off)"}
    ask = ask.strip()
    if not ask:
        return {"scope": "S", "rationale": "empty ask, default smallest"}

    inherited = _find_recent_scope_json()
    if inherited is not None:
        path, data = inherited
        return {
            "scope": data["scope"],
            "rationale": f"inherited from {path} (continuation of in-flight /ship run)",
        }

    prompt = PROMPT_TEMPLATE.format(ask=ask[:2000])
    cmd = [
        _resolve_claude_cmd(), "--bare", "-p",
        "--model", JUDGE_MODEL,
        "--output-format", "json",
        "--no-session-persistence",
        "--system-prompt", SYSTEM_PROMPT,
        prompt,
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=JUDGE_TIMEOUT_S)
    except (subprocess.TimeoutExpired, OSError):
        return {"scope": "S", "rationale": "classifier timeout, default smallest safe"}
    if r.returncode != 0:
        return {"scope": "S", "rationale": f"classifier exit={r.returncode}, default smallest safe"}

    try:
        env = json.loads(r.stdout)
        raw = env.get("result", "") if isinstance(env, dict) else r.stdout
    except json.JSONDecodeError:
        raw = r.stdout
    cleaned = _strip_fences(raw)
    obj_str = cleaned if cleaned.startswith("{") else _extract_json_object(cleaned)
    if not obj_str:
        return {"scope": "S", "rationale": "classifier no-JSON, default smallest safe"}
    try:
        verdict = json.loads(obj_str)
    except json.JSONDecodeError:
        return {"scope": "S", "rationale": "classifier parse-fail, default smallest safe"}
    scope = verdict.get("scope")
    if scope not in ("S", "M", "L", "XL"):
        return {"scope": "S", "rationale": f"classifier returned invalid scope={scope!r}"}
    return {"scope": scope, "rationale": verdict.get("rationale", "")[:300]}


def main(argv: list[str]) -> int:
    if len(argv) > 1:
        ask = " ".join(argv[1:])
    else:
        ask = sys.stdin.read()
    print(json.dumps(classify(ask)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
