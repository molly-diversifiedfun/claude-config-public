#!/usr/bin/env python3
"""Phase 8.0.7 — /ship preflight dependency check.

Probes external dependencies before /ship commits to running so we catch
"Notion API misconfigured / MCP missing / hit org API limits → no fallback"
sessions before they sink. /system-retro 2026-05-23 synthesis judge tagged
this as gap #4 ("Prerequisite Validation Skipped — likely root cause of 6+
stuck-mid-impl sessions").

Input: a list of deps to check, one per line. Source priority:
  1. `--deps <path>` argv
  2. `.ship/<run>/preflight-deps.txt` (orchestrator declares at Stage 1)
  3. stdin (if not a tty)

Dep formats supported:
  cmd:<name>           e.g. `cmd:gh` — checks `command -v <name>` is available
  env:<NAME>           e.g. `env:GITHUB_TOKEN` — checks env var is set + non-empty
  file:<path>          e.g. `file:~/.config/foo.json` — checks file exists + readable
  url:<https://...>    e.g. `url:https://api.github.com` — HEAD request, 2xx/3xx counts

Output: markdown report to stdout AND `.ship/<run>/preflight.json` (machine-
readable). Exit code 0 even if probes fail — preflight is a warning gate,
not a block (orchestrator decides whether to proceed).

Kill switch: SHIP_PREFLIGHT=off
Env-var overrides (testing):
  SHIP_PREFLIGHT_RUN_DIR     override .ship/<run>/ location for output
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib import request
from urllib.error import URLError, HTTPError

PROBE_TIMEOUT_S = 5
URL_TIMEOUT_S = 5


def kill_switch() -> bool:
    return os.environ.get("SHIP_PREFLIGHT", "on").lower() == "off"


def _probe_cmd(name: str) -> dict:
    path = shutil.which(name)
    return {
        "kind": "cmd", "target": name, "ok": path is not None,
        "detail": path or "not found in PATH",
    }


def _probe_env(name: str) -> dict:
    val = os.environ.get(name, "")
    return {
        "kind": "env", "target": name, "ok": bool(val),
        "detail": f"set ({len(val)} chars)" if val else "not set or empty",
    }


def _probe_file(path: str) -> dict:
    p = Path(path).expanduser()
    try:
        ok = p.exists() and os.access(p, os.R_OK)
    except OSError:
        ok = False
    return {
        "kind": "file", "target": str(p), "ok": ok,
        "detail": f"exists ({p.stat().st_size}B)" if ok else "missing or unreadable",
    }


def _probe_url(url: str) -> dict:
    req = request.Request(url, method="HEAD")
    try:
        with request.urlopen(req, timeout=URL_TIMEOUT_S) as r:
            code = r.status
            ok = 200 <= code < 400
            return {"kind": "url", "target": url, "ok": ok, "detail": f"HTTP {code}"}
    except HTTPError as e:
        # Server responded with an error — host is reachable, just not happy
        ok = 200 <= e.code < 400
        return {"kind": "url", "target": url, "ok": ok, "detail": f"HTTP {e.code}"}
    except (URLError, TimeoutError, OSError) as e:
        return {"kind": "url", "target": url, "ok": False, "detail": f"unreachable: {e}"}


def probe_one(dep: str) -> dict:
    """Dispatch a dep string like 'cmd:gh' to the right prober."""
    dep = dep.strip()
    if not dep or dep.startswith("#"):
        return {"kind": "skip", "target": dep, "ok": True, "detail": "blank/comment"}
    if ":" not in dep:
        return {"kind": "unknown", "target": dep, "ok": False,
                "detail": "no prefix (use cmd: / env: / file: / url:)"}
    kind, target = dep.split(":", 1)
    target = target.strip()
    if kind == "cmd":
        return _probe_cmd(target)
    if kind == "env":
        return _probe_env(target)
    if kind == "file":
        return _probe_file(target)
    if kind == "url":
        return _probe_url(target)
    return {"kind": "unknown", "target": dep, "ok": False,
            "detail": f"unknown prefix '{kind}'"}


def load_deps(argv: list[str]) -> tuple[list[str], str]:
    """Return (deps, source_label). Priority: --deps flag, .ship/<run>/preflight-deps.txt, stdin."""
    if len(argv) >= 3 and argv[1] == "--deps":
        path = Path(argv[2]).expanduser()
        if path.exists():
            return path.read_text().splitlines(), str(path)
    run_dir = os.environ.get("SHIP_PREFLIGHT_RUN_DIR")
    if run_dir:
        p = Path(run_dir) / "preflight-deps.txt"
        if p.exists():
            return p.read_text().splitlines(), str(p)
    # Auto-discover latest .ship/<run>/preflight-deps.txt in cwd
    ship = Path.cwd() / ".ship"
    if ship.is_dir():
        for run in sorted(ship.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
            p = run / "preflight-deps.txt"
            if p.exists():
                return p.read_text().splitlines(), str(p)
    if not sys.stdin.isatty():
        return sys.stdin.read().splitlines(), "stdin"
    return [], "(no deps)"


def render_report(results: list[dict], source: str) -> str:
    n = len(results)
    n_ok = sum(1 for r in results if r["ok"])
    n_fail = n - n_ok
    lines = [
        f"# /ship preflight",
        "",
        f"**Source:** `{source}`  •  **Probes:** {n}  •  **Passed:** {n_ok}  •  **Failed:** {n_fail}",
        "",
    ]
    if n_fail:
        lines.append(f"⚠️ {n_fail} probe(s) failed — review before continuing with /ship.")
        lines.append("")
    if not results:
        lines.append("_No deps to probe. Declare deps at `.ship/<run>/preflight-deps.txt` "
                     "(one per line, format `cmd:gh` / `env:GITHUB_TOKEN` / `file:~/.foo` / `url:https://...`)._")
        return "\n".join(lines)
    lines.append("| Probe | Result | Detail |")
    lines.append("|---|---|---|")
    for r in results:
        mark = "✅" if r["ok"] else "❌"
        lines.append(f"| `{r['kind']}:{r['target']}` | {mark} | {r['detail']} |")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if kill_switch():
        print("/ship preflight disabled (SHIP_PREFLIGHT=off)")
        return 0

    deps, source = load_deps(argv)
    # Drop blank lines and comment lines before probing so they never reach the report
    actionable = [d for d in deps if d.strip() and not d.strip().startswith("#")]
    results = [probe_one(d) for d in actionable]

    report = render_report(results, source)
    print(report)

    # Persist machine-readable JSON next to the deps file when possible
    if source.endswith("preflight-deps.txt"):
        json_path = Path(source).parent / "preflight.json"
        try:
            json_path.write_text(json.dumps({
                "source": source,
                "ts": time.time(),
                "results": results,
            }, indent=2))
            print(f"\n_JSON written to {json_path}_", file=sys.stderr)
        except OSError:
            pass

    # Exit 0 even on probe failures — preflight is a warning, not a block
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
