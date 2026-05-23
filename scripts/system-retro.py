#!/usr/bin/env python3
"""/system-retro — One-shot retrospective over recent Claude Code sessions.

Walks ~/.claude/projects/*/*.jsonl, takes the last N real sessions by mtime,
extracts per-session signals (mode used, tool counts, duration, first/last
messages), joins telemetry (git commits, hook blocks, agent-eval judgments),
runs a per-session Haiku judge on 4 dimensions, runs a synthesis judge over
the gap observations, and writes a markdown report.

Read-only. Soft-fails open on every external call.

Kill switch: SYSTEM_RETRO=off
Env-var overrides (testing):
  SYSTEM_RETRO_PROJECTS_DIR   override ~/.claude/projects
  SYSTEM_RETRO_HOOK_BLOCKS    override hook-blocks.log path
  SYSTEM_RETRO_AGENT_EVAL     override agent-eval.jsonl path
  SYSTEM_RETRO_REPORT_DIR     override report output dir
  SYSTEM_RETRO_N              override session count (default 20)
  SYSTEM_RETRO_NO_JUDGE       skip Haiku calls (extraction-only dry run)
  SYSTEM_RETRO_CLAUDE_CMD     override claude binary path (testing)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path

HOME = Path.home()
DEFAULT_PROJECTS_DIR = HOME / ".claude" / "projects"
DEFAULT_HOOK_BLOCKS = HOME / ".claude" / "logs" / "hook-blocks.log"
DEFAULT_AGENT_EVAL = HOME / ".claude" / "data" / "agent-eval.jsonl"
DEFAULT_REPORT_DIR = HOME / ".claude" / "data" / "system-retro"
DEFAULT_N = 20

JUDGE_MODEL = "claude-haiku-4-5-20251001"
JUDGE_TIMEOUT_S = 90
JUDGE_WORKERS = 8
JUDGE_WALL_S = 600  # 20 sessions * ~30s avg + buffer
SYNTH_TIMEOUT_S = 120

# Compressed transcript budget per session sent to judge
MSG_TRUNC = 400
MAX_MSGS_EACH_END = 2

MODE_PATTERNS = {
    "ship": re.compile(r"(?<![A-Za-z])/ship\b"),
    "build": re.compile(r"(?<![A-Za-z])/build\b"),
    "fix": re.compile(r"(?<![A-Za-z])/fix\b"),
    "write": re.compile(r"(?<![A-Za-z])/write\b"),
    "plan": re.compile(r"(?<![A-Za-z])/plan\b"),
    "review": re.compile(r"(?<![A-Za-z])/review\b"),
    "research": re.compile(r"(?<![A-Za-z])/research\b"),
}
SUPERPOWERS_RE = re.compile(r"superpowers:[a-z][a-z0-9-]*")
SMOKE_RE = re.compile(
    r"\b(smoke|smoked|verified.{0,30}(landed|prod|deploy)|DB row|event_kind|"
    r"prod.{0,20}(call|fire|invocation))\b",
    re.IGNORECASE,
)


def kill_switch() -> bool:
    return os.environ.get("SYSTEM_RETRO", "on").lower() == "off"


# === Session extraction ===

@dataclass
class SessionSummary:
    session_id: str
    project_slug: str
    cwd_guess: str | None
    transcript_path: str
    start_ts: str | None
    end_ts: str | None
    duration_min: float | None
    user_msg_count: int
    assistant_msg_count: int
    tool_call_count: int
    subagent_count: int
    first_user_msg: str
    last_user_msg: str
    last_assistant_msg: str
    mode_counts: dict[str, int]
    superpowers_used: list[str]
    dominant_mode: str
    smoke_evidence_hits: int
    # joined later
    commits: list[dict] = field(default_factory=list)
    hook_blocks: list[dict] = field(default_factory=list)
    agent_evals: list[dict] = field(default_factory=list)


def _extract_text(msg) -> str:
    """Pull plain text from a transcript message's content field (string or list)."""
    content = msg.get("content") if isinstance(msg, dict) else None
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text" and isinstance(block.get("text"), str):
                    parts.append(block["text"])
                elif block.get("type") == "tool_use":
                    parts.append(f"[tool:{block.get('name','?')}]")
                elif block.get("type") == "tool_result":
                    r = block.get("content")
                    if isinstance(r, str):
                        parts.append(f"[result:{r[:80]}]")
        return "\n".join(parts)
    return ""


def _scan_tool_uses(msg) -> tuple[int, int, list[str]]:
    """For one assistant message, return (tool_calls, subagent_dispatches, skills_invoked).

    `skills_invoked` is a list of `input.skill` values from `Skill` tool_use blocks
    — e.g. `["superpowers:subagent-driven-development", "bake-off", "commit-commands:commit"]`.
    Phase 7.7c.1 (2026-05-23): added to fix superpowers mode-detection undercount;
    the text-regex `SUPERPOWERS_RE` only matched when prose mentioned the literal
    skill name, which missed sessions that actually invoked superpowers via Skill().
    """
    if not isinstance(msg, dict):
        return 0, 0, []
    content = msg.get("content")
    if not isinstance(content, list):
        return 0, 0, []
    tools = subs = 0
    skills: list[str] = []
    for block in content:
        if not (isinstance(block, dict) and block.get("type") == "tool_use"):
            continue
        tools += 1
        name = block.get("name")
        if name in ("Agent", "Task"):
            subs += 1
        elif name == "Skill":
            sk = block.get("input", {}).get("skill")
            if isinstance(sk, str) and sk:
                skills.append(sk)
    return tools, subs, skills


_CWD_INDEX: dict[str, str] | None = None


def _path_to_slug(p: Path) -> str:
    """Claude Code's transcript-dir encoding: '/' and '.' both become '-'.
    Absolute paths start with '/' so the leading dash falls out of the replace.
    """
    return str(p).replace("/", "-").replace(".", "-")


def _build_cwd_index() -> dict[str, str]:
    """Walk likely cwd roots and build a slug→real-path map.

    Slug encoding is lossy (both '/' and '.' map to '-') so reverse-parsing
    a slug is unreliable for any path component containing dots OR hyphens.
    Build the index forward instead: walk real candidate dirs and compute
    each one's slug. First match wins.
    """
    global _CWD_INDEX
    if _CWD_INDEX is not None:
        return _CWD_INDEX
    index: dict[str, str] = {}
    home = Path.home()
    roots = [home, home / "github", home / "Desktop", home / "Downloads",
             home / ".claude", Path("/private/tmp"), Path("/tmp")]
    for root in roots:
        if not root.exists():
            continue
        try:
            for entry in root.iterdir():
                if entry.is_dir():
                    index.setdefault(_path_to_slug(entry), str(entry))
                    # one level deeper too — catches `~/github/sub/proj` etc.
                    try:
                        for sub in entry.iterdir():
                            if sub.is_dir():
                                index.setdefault(_path_to_slug(sub), str(sub))
                    except (OSError, PermissionError):
                        continue
        except (OSError, PermissionError):
            continue
    # Always index home itself for the bare `~` slug
    index.setdefault(_path_to_slug(home), str(home))
    _CWD_INDEX = index
    return index


def _slug_to_cwd(slug: str) -> str | None:
    """Resolve a transcript dir slug to a real cwd by forward-built index."""
    if not slug.startswith("-"):
        return None
    return _build_cwd_index().get(slug)


def extract_session(jsonl_path: Path) -> SessionSummary | None:
    """Parse one session transcript jsonl into a SessionSummary.

    Returns None for transcripts with no user messages (metadata-only files).
    """
    if not jsonl_path.exists() or jsonl_path.stat().st_size == 0:
        return None

    session_id = jsonl_path.stem
    project_slug = jsonl_path.parent.name
    cwd_guess = _slug_to_cwd(project_slug)

    user_msgs: list[tuple[str, str]] = []  # (ts, text)
    asst_msgs: list[tuple[str, str]] = []
    tool_count = 0
    sub_count = 0
    skills_invoked: list[str] = []
    first_ts = None
    last_ts = None

    try:
        with jsonl_path.open() as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                t = rec.get("type")
                ts = rec.get("timestamp")
                if ts:
                    if first_ts is None:
                        first_ts = ts
                    last_ts = ts
                if t == "user":
                    text = _extract_text(rec.get("message", {}))
                    if text.strip():
                        user_msgs.append((ts or "", text))
                elif t == "assistant":
                    msg = rec.get("message", {})
                    text = _extract_text(msg)
                    asst_msgs.append((ts or "", text))
                    tc, sc, sks = _scan_tool_uses(msg)
                    tool_count += tc
                    sub_count += sc
                    skills_invoked.extend(sks)
    except OSError:
        return None

    if not user_msgs:
        return None

    full_text = " ".join(t for _, t in user_msgs + asst_msgs)
    mode_counts = {k: len(p.findall(full_text)) for k, p in MODE_PATTERNS.items()}
    # Union text-regex matches (covers user-prose mentions like "use superpowers:foo")
    # with actual tool_use Skill invocations (covers structured Skill() calls).
    sp_from_text = set(SUPERPOWERS_RE.findall(full_text))
    sp_from_tools = {s for s in skills_invoked if s.startswith("superpowers:")}
    superpowers = sorted(sp_from_text | sp_from_tools)
    smoke_hits = len(SMOKE_RE.findall(full_text))

    # Dominant mode: highest slash-command count; tiebreak by superpowers presence; else 'raw'
    nonzero = [(k, v) for k, v in mode_counts.items() if v > 0]
    if nonzero:
        dominant = max(nonzero, key=lambda kv: kv[1])[0]
    elif superpowers:
        dominant = "superpowers"
    else:
        dominant = "raw"

    duration_min = None
    if first_ts and last_ts:
        try:
            d0 = datetime.fromisoformat(first_ts.replace("Z", "+00:00"))
            d1 = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
            duration_min = round((d1 - d0).total_seconds() / 60, 1)
        except ValueError:
            pass

    return SessionSummary(
        session_id=session_id,
        project_slug=project_slug,
        cwd_guess=cwd_guess,
        transcript_path=str(jsonl_path),
        start_ts=first_ts,
        end_ts=last_ts,
        duration_min=duration_min,
        user_msg_count=len(user_msgs),
        assistant_msg_count=len(asst_msgs),
        tool_call_count=tool_count,
        subagent_count=sub_count,
        first_user_msg=user_msgs[0][1][:MSG_TRUNC],
        last_user_msg=user_msgs[-1][1][:MSG_TRUNC],
        last_assistant_msg=(asst_msgs[-1][1] if asst_msgs else "")[:MSG_TRUNC],
        mode_counts=mode_counts,
        superpowers_used=superpowers,
        dominant_mode=dominant,
        smoke_evidence_hits=smoke_hits,
    )


MIN_SESSION_BYTES = 4000  # transient metadata-only transcripts spawned by
                          # `claude --bare` calls weigh ~130 B (ai-title +
                          # last-prompt + permission-mode lines, no actual
                          # conversation). Real sessions are KB+ minimum.

# Aggregate-only filters (Phase 8.0 follow-up, 2026-05-23): tiny abandoned
# sessions (e.g. context-corrupted <your-project-2> shells that fired 0-2
# tool calls in <2 min) get judged "stuck-mid-impl" automatically and drag
# the per-mode averages. They stay in the raw session table for transparency
# but are excluded from per-mode aggregation when EITHER threshold is missed.
MIN_AGG_DURATION_MIN = 5.0
MIN_AGG_TOOL_CALLS = 5


def discover_recent_sessions(projects_dir: Path, n: int,
                             min_bytes: int = MIN_SESSION_BYTES) -> list[Path]:
    """Find the N most recent real session transcripts.

    Excludes agent-*.jsonl (subagent dispatches), zero-byte files, and
    metadata-only files below `min_bytes` (Claude Code spawns these for
    every `claude --bare` invocation; they have no user/assistant content).
    """
    if not projects_dir.exists():
        return []
    candidates: list[tuple[float, Path]] = []
    for proj_dir in projects_dir.iterdir():
        if not proj_dir.is_dir():
            continue
        for jsonl in proj_dir.glob("*.jsonl"):
            name = jsonl.name
            if name.startswith("agent-"):
                continue
            try:
                st = jsonl.stat()
            except OSError:
                continue
            if st.st_size < min_bytes:
                continue
            candidates.append((st.st_mtime, jsonl))
    candidates.sort(key=lambda x: x[0], reverse=True)
    return [p for _, p in candidates[:n]]


# === Telemetry joins ===

def _parse_iso(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def join_git_commits(cwd: str | None, start: str | None, end: str | None) -> list[dict]:
    """git log within the session window. Returns [] on any failure."""
    if not cwd or not start or not end:
        return []
    if not Path(cwd).exists() or not (Path(cwd) / ".git").exists():
        return []
    try:
        out = subprocess.run(
            ["git", "log", f"--since={start}", f"--until={end}",
             "--pretty=format:%h|%s"],
            cwd=cwd, capture_output=True, text=True, timeout=10,
        )
        if out.returncode != 0:
            return []
        commits = []
        for line in out.stdout.strip().split("\n"):
            if "|" in line:
                h, s = line.split("|", 1)
                commits.append({"sha": h, "subject": s[:120]})
        return commits
    except (subprocess.TimeoutExpired, OSError):
        return []


def join_hook_blocks(blocks_path: Path, start: str | None, end: str | None,
                     cwd: str | None) -> list[dict]:
    """Filter ~/.claude/logs/hook-blocks.log to entries in session window for this cwd."""
    if not blocks_path.exists() or not start or not end:
        return []
    s_dt = _parse_iso(start)
    e_dt = _parse_iso(end)
    if not s_dt or not e_dt:
        return []
    out = []
    try:
        with blocks_path.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = _parse_iso(rec.get("timestamp") or rec.get("ts"))
                if not ts or not (s_dt <= ts <= e_dt):
                    continue
                if cwd and rec.get("cwd") and rec["cwd"] != cwd:
                    continue
                out.append({
                    "hook": rec.get("hook", "?"),
                    "reason": (rec.get("reason") or rec.get("message") or "")[:120],
                })
    except OSError:
        return []
    return out


def join_agent_evals(eval_path: Path, start: str | None, end: str | None) -> list[dict]:
    """Filter agent-eval.jsonl to judgments inside the session window."""
    if not eval_path.exists() or not start or not end:
        return []
    s_dt = _parse_iso(start)
    e_dt = _parse_iso(end)
    if not s_dt or not e_dt:
        return []
    out = []
    try:
        with eval_path.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = _parse_iso(rec.get("judged_at") or rec.get("timestamp") or rec.get("ts"))
                if not ts or not (s_dt <= ts <= e_dt):
                    continue
                out.append({
                    "used_injected_skill": rec.get("used_injected_skill"),
                    "which_skill": rec.get("which_skill"),
                    "quality_score": rec.get("quality_score"),
                })
    except OSError:
        return []
    return out


# === Judge ===

JUDGE_SYSTEM = (
    "You evaluate Claude Code sessions for process quality. "
    "Your ENTIRE response must be a single JSON object, no prose before or after, "
    "no markdown fences. Start with '{' and end with '}'."
)

# Minimal schema (no enum, no maxLength) — Haiku 4.5 + --json-schema returns
# empty `result` on richer constraints. Process pattern is a free string that
# we bucket post-hoc in render_report().
JUDGE_SCHEMA = {
    "type": "object",
    "properties": {
        "shipped_and_smoked": {"type": "integer", "minimum": 1, "maximum": 5},
        "incremental_value": {"type": "integer", "minimum": 1, "maximum": 5},
        "mode_fit": {"type": "integer", "minimum": 1, "maximum": 5},
        "time_to_done_vs_scope": {"type": "integer", "minimum": 1, "maximum": 5},
        "primary_gap": {"type": "string"},
        "process_pattern": {"type": "string"},
    },
    "required": [
        "shipped_and_smoked", "incremental_value", "mode_fit",
        "time_to_done_vs_scope", "primary_gap", "process_pattern",
    ],
}


def _build_judge_prompt(s: SessionSummary) -> str:
    commits_str = "\n".join(f"  - {c['sha']} {c['subject']}" for c in s.commits[:10]) or "  (none)"
    blocks_str = "\n".join(f"  - {b['hook']}: {b['reason']}" for b in s.hook_blocks[:5]) or "  (none)"
    evals_str = "\n".join(
        f"  - used={e['used_injected_skill']} which={e['which_skill']} score={e['quality_score']}"
        for e in s.agent_evals[:5]
    ) or "  (none)"
    mode_str = ", ".join(f"{k}={v}" for k, v in s.mode_counts.items() if v > 0) or "none"
    sp_str = ", ".join(s.superpowers_used[:8]) or "none"

    return f"""SESSION SUMMARY
project: {s.project_slug}
duration_min: {s.duration_min}
user_msgs: {s.user_msg_count}  assistant_msgs: {s.assistant_msg_count}
tool_calls: {s.tool_call_count}  subagent_dispatches: {s.subagent_count}
dominant_mode: {s.dominant_mode}
slash_commands: {mode_str}
superpowers_skills: {sp_str}
smoke_evidence_text_hits: {s.smoke_evidence_hits}

FIRST USER PROMPT (the ask):
{s.first_user_msg}

LAST USER PROMPT (final direction):
{s.last_user_msg}

LAST ASSISTANT MESSAGE (final output):
{s.last_assistant_msg}

JOINED TELEMETRY
git commits in window:
{commits_str}
hook blocks in window:
{blocks_str}
agent-eval judgments in window:
{evals_str}

Score each dimension 1-5 (3=ambiguous, 1=positive evidence of failure, 5=positive evidence of success):
- shipped_and_smoked: did work land in code AND get verified? Commits + smoke evidence = high.
- incremental_value: did the session produce something independently useful, or leave half-finished work?
- mode_fit: was the chosen mode (slash command / raw / superpowers) the right tool for this ask?
- time_to_done_vs_scope: did the session stay on original scope, or did it sprawl?

primary_gap: ONE sentence on the biggest process gap (or "none" if clean).
process_pattern: short kebab-case label, one of:
  shipped-clean | shipped-no-smoke | shipped-scope-creep | stuck-mid-impl |
  research-only | planning-only | abandoned | calibration-followup |
  tooling-meta | unclear

Respond with ONLY this JSON object (no prose, no fences):
{{"shipped_and_smoked":<1-5>,"incremental_value":<1-5>,"mode_fit":<1-5>,"time_to_done_vs_scope":<1-5>,"primary_gap":"<one sentence>","process_pattern":"<label>"}}"""


def _resolve_claude_cmd() -> str:
    return os.environ.get("SYSTEM_RETRO_CLAUDE_CMD") or "claude"


def _strip_fences(s: str) -> str:
    s = s.strip()
    if s.startswith("```"):
        s = re.sub(r"^```[a-zA-Z]*\n", "", s)
        s = re.sub(r"\n```\s*$", "", s)
    return s.strip()


def _run_claude(prompt: str, system: str, timeout_s: int,
                schema: dict | None = None) -> str | None:
    """Invoke `claude --bare -p`. Prompt as positional arg (not stdin) per
    consolidate-skills.py's pattern. With `schema`, adds `--json-schema` to
    force structured output (essential for Haiku — without it Haiku will
    prose its way to the answer).
    """
    cmd = [
        _resolve_claude_cmd(), "--bare", "-p",
        "--model", JUDGE_MODEL,
        "--output-format", "json",
        "--no-session-persistence",
        "--system-prompt", system,
    ]
    if schema is not None:
        cmd.extend(["--json-schema", json.dumps(schema)])
    cmd.append(prompt)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
    except (subprocess.TimeoutExpired, OSError):
        return None
    if r.returncode != 0:
        return None
    try:
        env = json.loads(r.stdout)
    except json.JSONDecodeError:
        return r.stdout  # bare text fallback
    inner = env.get("result") if isinstance(env, dict) else None
    return inner if isinstance(inner, str) else r.stdout


def _extract_json_object(s: str) -> str | None:
    """Find the first {...} JSON object in a string, returns it or None."""
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


def judge_session(s: SessionSummary) -> dict | None:
    """Per-session judge. Retry-once-on-bad-JSON. Returns verdict dict or None.

    No --json-schema (Haiku 4.5 returns empty `result` under structured-output
    mode for this prompt shape). Instead: strict system-prompt + inline JSON
    template in the user prompt + defensive object extraction.
    """
    prompt = _build_judge_prompt(s)
    for attempt in range(2):
        raw = _run_claude(prompt, JUDGE_SYSTEM, JUDGE_TIMEOUT_S)
        if not raw:
            continue
        cleaned = _strip_fences(raw)
        obj_str = cleaned if cleaned.startswith("{") else _extract_json_object(cleaned)
        if not obj_str:
            continue
        try:
            verdict = json.loads(obj_str)
        except json.JSONDecodeError:
            continue
        if all(k in verdict for k in JUDGE_SCHEMA["required"]):
            verdict["session_id"] = s.session_id
            return verdict
    return None


def synthesize(verdicts: list[dict]) -> str:
    """Cross-cutting synthesis judge: themes across primary_gap strings."""
    if not verdicts:
        return "(no verdicts to synthesize)"
    bullets = "\n".join(
        f"- mode={v.get('dominant_mode','?')} pattern={v.get('process_pattern','?')}: {v.get('primary_gap','')}"
        for v in verdicts
    )
    prompt = f"""You have process-gap notes from {len(verdicts)} recent sessions:

{bullets}

In 4-6 bullets, name the CROSS-CUTTING THEMES — patterns that appear across multiple sessions, not one-offs. For each theme, name (a) what pattern recurs, (b) which mode it shows up most in, (c) one concrete fix.

Markdown bullets only. No preamble."""
    raw = _run_claude(prompt, "You are synthesizing process retrospectives. Be concrete and evidence-based.", SYNTH_TIMEOUT_S)
    return raw.strip() if raw else "(synthesis judge failed)"


# === Report ===

def _passes_aggregate_floor(s: SessionSummary | None) -> bool:
    """Per Phase 8.0 follow-up: only count sessions in aggregates when they
    have enough signal to mean anything. Tiny abandoned sessions stay in the
    raw table but are excluded from per-mode averages.
    """
    if s is None:
        return False
    if s.duration_min is not None and s.duration_min < MIN_AGG_DURATION_MIN:
        return False
    if s.tool_call_count < MIN_AGG_TOOL_CALLS:
        return False
    return True


def render_report(summaries: list[SessionSummary], verdicts: list[dict],
                  synthesis: str, used_judge: bool) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    n = len(summaries)
    sum_by_id = {s.session_id: s for s in summaries}
    excluded_ct = sum(1 for s in summaries if not _passes_aggregate_floor(s))
    lines = [
        f"# System Retrospective — {now}",
        "",
        f"**Sessions analyzed:** {n} most recent (excludes subagent dispatches and zero-byte transcripts).",
        f"**Judge:** {'enabled — Haiku 4.5 per-session + synthesis' if used_judge else 'DISABLED (extraction-only)'}.",
        f"**Aggregate floor:** sessions with duration < {MIN_AGG_DURATION_MIN}min OR tools < {MIN_AGG_TOOL_CALLS} are kept in the raw table but excluded from per-mode averages ({excluded_ct}/{n} excluded this run).",
        "",
        "## Per-mode aggregates",
        "",
    ]

    by_mode: dict[str, list[dict]] = {}
    for v in verdicts:
        sid = v.get("session_id")
        s = sum_by_id.get(sid)
        mode = s.dominant_mode if s else "?"
        v["dominant_mode"] = mode
        # Aggregate-floor filter — exclude tiny abandoned sessions
        if _passes_aggregate_floor(s):
            by_mode.setdefault(mode, []).append(v)

    if verdicts:
        lines.append("| Mode | N | Shipped+Smoked | Incremental | Mode-Fit | Scope |")
        lines.append("|---|---:|---:|---:|---:|---:|")
        for mode, vs in sorted(by_mode.items(), key=lambda kv: -len(kv[1])):
            def avg(k):
                xs = [v.get(k) for v in vs if isinstance(v.get(k), (int, float))]
                return f"{sum(xs)/len(xs):.1f}" if xs else "—"
            lines.append(
                f"| {mode} | {len(vs)} | {avg('shipped_and_smoked')} | "
                f"{avg('incremental_value')} | {avg('mode_fit')} | "
                f"{avg('time_to_done_vs_scope')} |"
            )
        lines.append("")
        lines.append("## Process patterns observed")
        lines.append("")
        pattern_counts: dict[str, int] = {}
        for v in verdicts:
            p = v.get("process_pattern", "unclear")
            pattern_counts[p] = pattern_counts.get(p, 0) + 1
        for p, c in sorted(pattern_counts.items(), key=lambda kv: -kv[1]):
            lines.append(f"- **{p}** — {c} session(s)")
        lines.append("")

        lines.append("## Exemplars (highest combined score)")
        lines.append("")
        def combined(v):
            return sum(v.get(k, 0) for k in (
                "shipped_and_smoked", "incremental_value", "mode_fit", "time_to_done_vs_scope"
            ))
        top = sorted(verdicts, key=combined, reverse=True)[:3]
        bot = sorted(verdicts, key=combined)[:3]
        for v in top:
            s = sum_by_id.get(v.get("session_id"))
            lines.append(_session_card(s, v))
        lines.append("## Anti-exemplars (lowest combined score)")
        lines.append("")
        for v in bot:
            s = sum_by_id.get(v.get("session_id"))
            lines.append(_session_card(s, v))

        lines.append("## Cross-cutting themes (synthesis)")
        lines.append("")
        lines.append(synthesis)
        lines.append("")

    lines.append("## Raw session table")
    lines.append("")
    lines.append("| Session | Project | Mode | Dur (min) | Tools | Subagents | Commits | Blocks |")
    lines.append("|---|---|---|---:|---:|---:|---:|---:|")
    for s in summaries:
        proj = s.project_slug.replace("<your-workspace>-", "…/")[:30]
        lines.append(
            f"| `{s.session_id[:8]}` | {proj} | {s.dominant_mode} | "
            f"{s.duration_min or '—'} | {s.tool_call_count} | {s.subagent_count} | "
            f"{len(s.commits)} | {len(s.hook_blocks)} |"
        )
    lines.append("")
    return "\n".join(lines)


def _session_card(s: SessionSummary | None, v: dict) -> str:
    if not s:
        return f"- _(missing session for {v.get('session_id')})_\n"
    proj = s.project_slug.replace("<your-workspace>-", "…/")
    ask = s.first_user_msg.split("\n")[0][:160]
    gap = v.get("primary_gap", "—")
    return (
        f"### `{s.session_id[:8]}` — {proj}\n\n"
        f"- **mode:** {s.dominant_mode}  •  **scores:** "
        f"ship={v.get('shipped_and_smoked')} incr={v.get('incremental_value')} "
        f"fit={v.get('mode_fit')} scope={v.get('time_to_done_vs_scope')}  •  "
        f"**pattern:** {v.get('process_pattern')}\n"
        f"- **ask:** {ask}\n"
        f"- **gap:** {gap}\n\n"
    )


# === Main ===

def main(argv: list[str]) -> int:
    if kill_switch():
        print("/system-retro disabled (SYSTEM_RETRO=off)")
        return 0

    projects_dir = Path(os.environ.get("SYSTEM_RETRO_PROJECTS_DIR", DEFAULT_PROJECTS_DIR))
    blocks_path = Path(os.environ.get("SYSTEM_RETRO_HOOK_BLOCKS", DEFAULT_HOOK_BLOCKS))
    eval_path = Path(os.environ.get("SYSTEM_RETRO_AGENT_EVAL", DEFAULT_AGENT_EVAL))
    report_dir = Path(os.environ.get("SYSTEM_RETRO_REPORT_DIR", DEFAULT_REPORT_DIR))
    n = int(os.environ.get("SYSTEM_RETRO_N", DEFAULT_N))
    no_judge = os.environ.get("SYSTEM_RETRO_NO_JUDGE", "").lower() in ("1", "true", "on")

    report_dir.mkdir(parents=True, exist_ok=True)

    t0 = time.time()
    paths = discover_recent_sessions(projects_dir, n)
    print(f"[retro] discovered {len(paths)} recent sessions in {time.time()-t0:.1f}s",
          file=sys.stderr)

    summaries: list[SessionSummary] = []
    for p in paths:
        s = extract_session(p)
        if s is None:
            continue
        s.commits = join_git_commits(s.cwd_guess, s.start_ts, s.end_ts)
        s.hook_blocks = join_hook_blocks(blocks_path, s.start_ts, s.end_ts, s.cwd_guess)
        s.agent_evals = join_agent_evals(eval_path, s.start_ts, s.end_ts)
        summaries.append(s)

    print(f"[retro] extracted {len(summaries)} sessions with content", file=sys.stderr)

    verdicts: list[dict] = []
    synthesis = "(judge disabled)"
    if not no_judge and summaries:
        print(f"[retro] judging {len(summaries)} sessions in parallel "
              f"(workers={JUDGE_WORKERS}, per-call={JUDGE_TIMEOUT_S}s)", file=sys.stderr)
        t_judge = time.time()
        with ThreadPoolExecutor(max_workers=JUDGE_WORKERS) as pool:
            futures = {pool.submit(judge_session, s): s for s in summaries}
            for fut in as_completed(futures, timeout=JUDGE_WALL_S):
                try:
                    v = fut.result()
                except Exception as e:
                    print(f"[retro] judge worker exception: {e}", file=sys.stderr)
                    v = None
                if v:
                    verdicts.append(v)
            pool.shutdown(wait=False, cancel_futures=True)
        print(f"[retro] judge: {len(verdicts)}/{len(summaries)} verdicts in "
              f"{time.time()-t_judge:.1f}s", file=sys.stderr)

        # Attach dominant_mode into verdicts before synthesis
        sum_by_id = {s.session_id: s for s in summaries}
        for v in verdicts:
            v["dominant_mode"] = sum_by_id[v["session_id"]].dominant_mode

        synthesis = synthesize(verdicts)

    used_judge = not no_judge and bool(verdicts)
    report = render_report(summaries, verdicts, synthesis, used_judge)
    iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    out = report_dir / f"{iso}.md"
    out.write_text(report)
    print(str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
