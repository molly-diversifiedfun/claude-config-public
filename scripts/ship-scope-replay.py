#!/usr/bin/env python3
"""Phase 8.0.6 — /ship scope-replay tool.

Classifies the first real user prompt of recent sessions through Stage 0
(ship-scope-classify.py) and renders a markdown table comparing the
prescribed scope to actual outcome metadata (mode, duration, tools, skills).

Useful for:
  - Validating classifier calibration against historical asks (the 2026-05-23
    dogfood replay found "lets do step N" misclassified as S, leading to
    Phase 8.0.4 continuation rule + 8.0.5 scope inheritance fixes)
  - Spotting under-tier / over-tier patterns when new heuristics ship
  - Auditing classifier behavior after prompt-template changes

Read-only. Soft-fails open on every external call. Skips system-generated
"summary" prompts and Stop-hook-feedback "asks" that aren't real user input.

Kill switch: SHIP_SCOPE_REPLAY=off
Env-var overrides (testing):
  SHIP_SCOPE_REPLAY_PROJECTS_DIR  override ~/.claude/projects
  SHIP_SCOPE_REPLAY_CLASSIFIER    override path to ship-scope-classify.py
  SHIP_SCOPE_REPLAY_REPORT_DIR    override report output dir
  SHIP_SCOPE_REPLAY_N             override session count (default 30)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
DEFAULT_PROJECTS_DIR = HOME / ".claude" / "projects"
DEFAULT_CLASSIFIER = HOME / ".claude" / "scripts" / "ship-scope-classify.py"
DEFAULT_REPORT_DIR = HOME / ".claude" / "data" / "scope-replay-reports"
DEFAULT_N = 30

# Reuses Phase 7.7c minimum file size — under this is metadata-only `claude --bare` spawn
MIN_SESSION_BYTES = 4000

# Skip patterns that aren't real user asks (system-generated, hook feedback, caveats)
SKIP_PREFIXES = (
    "<local-command",
    "<bash-stdout",
    "<bash-stderr",
    "Context: This summary will be shown",
    "Stop hook feedback:",
    "[Request interrupted",
    "Caveat:",
)

CLASSIFIER_TIMEOUT_S = 60
PARALLEL_WORKERS = 6
WALL_BUDGET_S = 600


def kill_switch() -> bool:
    return os.environ.get("SHIP_SCOPE_REPLAY", "on").lower() == "off"


def _is_real_ask(text: str) -> bool:
    t = text.strip()
    if not t or len(t) < 15:
        return False
    if any(t.startswith(p) for p in SKIP_PREFIXES):
        return False
    if t.startswith("<") and t.endswith(">"):
        return False
    return True


def first_real_ask(jsonl_path: Path) -> str | None:
    """Return the first non-system user prompt, or None if only auto-generated asks."""
    try:
        with jsonl_path.open() as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("type") != "user":
                    continue
                content = rec.get("message", {}).get("content")
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    text = "\n".join(
                        b.get("text", "") for b in content
                        if isinstance(b, dict) and b.get("type") == "text"
                    )
                else:
                    continue
                if _is_real_ask(text):
                    return text.strip()
    except OSError:
        pass
    return None


def extract_meta(jsonl_path: Path) -> dict:
    """Return {tools, dur_min, skills} from a transcript."""
    tools = 0
    first_ts = last_ts = None
    skills: list[str] = []
    try:
        with jsonl_path.open() as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = rec.get("timestamp")
                if ts:
                    if first_ts is None:
                        first_ts = ts
                    last_ts = ts
                if rec.get("type") != "assistant":
                    continue
                content = rec.get("message", {}).get("content")
                if not isinstance(content, list):
                    continue
                for block in content:
                    if not (isinstance(block, dict) and block.get("type") == "tool_use"):
                        continue
                    tools += 1
                    if block.get("name") == "Skill":
                        sk = block.get("input", {}).get("skill")
                        if isinstance(sk, str) and sk:
                            skills.append(sk)
    except OSError:
        pass
    dur_min = None
    if first_ts and last_ts:
        try:
            d0 = datetime.fromisoformat(first_ts.replace("Z", "+00:00"))
            d1 = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
            dur_min = round((d1 - d0).total_seconds() / 60, 1)
        except (ValueError, AttributeError):
            pass
    return {"tools": tools, "dur_min": dur_min, "skills": skills}


def discover_sessions(projects_dir: Path, n: int) -> list[Path]:
    """Most-recent N session transcripts, excluding agent-* and small metadata files."""
    if not projects_dir.exists():
        return []
    candidates: list[tuple[float, Path]] = []
    for proj_dir in projects_dir.iterdir():
        if not proj_dir.is_dir():
            continue
        for jsonl in proj_dir.glob("*.jsonl"):
            if jsonl.name.startswith("agent-"):
                continue
            try:
                st = jsonl.stat()
            except OSError:
                continue
            if st.st_size < MIN_SESSION_BYTES:
                continue
            candidates.append((st.st_mtime, jsonl))
    candidates.sort(key=lambda x: x[0], reverse=True)
    return [p for _, p in candidates[:n]]


def classify(ask: str, classifier_path: str) -> dict:
    """Invoke the classifier on one ask. Returns {scope, rationale}."""
    try:
        r = subprocess.run(
            ["python3", classifier_path, ask[:1500]],
            capture_output=True, text=True, timeout=CLASSIFIER_TIMEOUT_S,
        )
    except (subprocess.TimeoutExpired, OSError):
        return {"scope": "?", "rationale": "classifier timeout"}
    if r.returncode != 0:
        return {"scope": "?", "rationale": f"classifier exit={r.returncode}"}
    try:
        return json.loads(r.stdout.strip())
    except json.JSONDecodeError:
        return {"scope": "?", "rationale": "classifier parse fail"}


def render_report(rows: list[dict], n_discovered: int, n_classified: int) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines = [
        f"# Scope-Replay Report — {now}",
        "",
        f"**Sessions discovered:** {n_discovered} most-recent (excludes subagent dispatches and metadata-only files <{MIN_SESSION_BYTES}B).",
        f"**Sessions classified:** {n_classified} (skipped: no real user prompt found — only auto-summaries / hook-feedback / caveats).",
        "",
        "## Per-scope distribution",
        "",
    ]
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["verdict"]["scope"]] = counts.get(r["verdict"]["scope"], 0) + 1
    lines.append("| Scope | N |")
    lines.append("|---|---:|")
    for scope in ("S", "M", "L", "XL", "?"):
        c = counts.get(scope, 0)
        if c > 0:
            lines.append(f"| **{scope}** | {c} |")
    lines.append("")
    lines.append("## Per-session classifications")
    lines.append("")
    lines.append("| Session | Project | Scope | Dur (min) | Tools | Skills invoked | Ask preview |")
    lines.append("|---|---|---|---:|---:|---|---|")
    for r in rows:
        proj = r["proj"].replace("<your-workspace>-", "…/")[:25]
        ask = r["ask"][:80].replace("|", "\\|").replace("\n", " ")
        skills = ",".join(s.split(":", 1)[-1][:18] for s in r["meta"]["skills"][:3])
        lines.append(
            f"| `{r['sid'][:8]}` | {proj} | **{r['verdict']['scope']}** | "
            f"{r['meta']['dur_min'] or '—'} | {r['meta']['tools']} | "
            f"{skills} | {ask} |"
        )
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if kill_switch():
        print("/ship-scope-replay disabled (SHIP_SCOPE_REPLAY=off)")
        return 0

    projects_dir = Path(os.environ.get("SHIP_SCOPE_REPLAY_PROJECTS_DIR", DEFAULT_PROJECTS_DIR))
    classifier = os.environ.get("SHIP_SCOPE_REPLAY_CLASSIFIER", str(DEFAULT_CLASSIFIER))
    report_dir = Path(os.environ.get("SHIP_SCOPE_REPLAY_REPORT_DIR", DEFAULT_REPORT_DIR))
    n = int(os.environ.get("SHIP_SCOPE_REPLAY_N", argv[1] if len(argv) > 1 else DEFAULT_N))

    report_dir.mkdir(parents=True, exist_ok=True)

    paths = discover_sessions(projects_dir, n)
    print(f"[replay] discovered {len(paths)} sessions", file=sys.stderr)

    rows: list[dict] = []
    for p in paths:
        ask = first_real_ask(p)
        if ask is None:
            continue
        meta = extract_meta(p)
        rows.append({"sid": p.stem, "proj": p.parent.name, "ask": ask, "meta": meta})
    print(f"[replay] {len(rows)} sessions with real asks after filtering", file=sys.stderr)

    if not rows:
        print(render_report([], len(paths), 0))
        return 0

    print(f"[replay] classifying {len(rows)} sessions in parallel (workers={PARALLEL_WORKERS})",
          file=sys.stderr)
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=PARALLEL_WORKERS) as pool:
        futs = {pool.submit(classify, r["ask"], classifier): r for r in rows}
        for fut in as_completed(futs, timeout=WALL_BUDGET_S):
            r = futs[fut]
            try:
                r["verdict"] = fut.result()
            except Exception as e:
                r["verdict"] = {"scope": "?", "rationale": f"worker exception: {e}"}
        pool.shutdown(wait=False, cancel_futures=True)
    print(f"[replay] classified in {time.time()-t0:.1f}s", file=sys.stderr)

    report = render_report(rows, len(paths), len(rows))
    iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    out = report_dir / f"{iso}.md"
    out.write_text(report)
    print(str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
