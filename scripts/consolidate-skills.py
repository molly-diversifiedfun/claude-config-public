#!/usr/bin/env python3
"""Phase 7.7a — Skill catalog consolidator.

Scans installed skills under ~/.claude/skills/ + ~/.claude/plugins/cache/**/skills/
and emits a tiered markdown report of consolidation candidates by composite score
(desc Jaccard 0.35 + body Jaccard 0.20 + bake-off shared losses 0.30 + Phase 7.4 elim 0.15).

Read-only. No auto-apply. Soft-fails open everywhere.

Kill switch: SKILL_CONSOLIDATE=off
Env-var overrides (testing):
  SKILL_CONSOLIDATE_ROOTS  colon-separated skill roots (default: user + plugin cache)
  BAKEOFF_LOG_FILE         path to bake-off-log.jsonl
  BAKEOFF_STATS_FILE       path to bake-off-stats.tsv
  REPORT_DIR               output dir
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

# === Configuration ===
HOME = Path.home()
DEFAULT_ROOTS = f"{HOME}/.claude/skills:{HOME}/.claude/plugins/cache"
DEFAULT_LOG = f"{HOME}/.claude/data/bake-off-log.jsonl"
DEFAULT_STATS = f"{HOME}/.claude/data/bake-off-stats.tsv"
DEFAULT_REPORT_DIR = f"{HOME}/.claude/data/skill-consolidation-reports"
STOPWORDS_SOURCE = f"{HOME}/.claude/scripts/skills-prefilter.sh"

# Body extraction regexes — frontmatter anchored at start-of-file (count=1),
# fenced code blocks stripped greedily on content, non-greedy on bounds.
_FRONTMATTER_RE = re.compile(r"^---\n.*?\n---\n", re.DOTALL)
_FENCED_CODE_RE = re.compile(r"```[^\n]*\n.*?\n```\n?", re.DOTALL)

W_DESC = 0.35
W_BODY = 0.20
W_LOSSES = 0.30
W_ELIM = 0.15
LOSSES_CAP = 5

TIER_HIGH = 0.55
TIER_MEDIUM = 0.30
TIER_LOW = 0.15
TIER_CAP = 50  # max pairs per tier in the rendered report (sorted by composite desc)

# === Phase 7.7a.2 — LLM-judge ===
JUDGE_MODEL = "claude-haiku-4-5-20251001"
JUDGE_TIMEOUT_S = 60
JUDGE_WALL_S = 180
JUDGE_MAX_PAIRS = 1000
JUDGE_WORKERS = 8
JUDGE_BODY_TRUNC = 4000
JUDGE_RATIONALE_MAX = 300
JUDGE_AMBIGUITY_LO = 0.15
JUDGE_AMBIGUITY_HI = 0.30
JUDGE_CONFIDENCE_FLOOR = 4
JUDGE_TIER_CAP = 20

DEFAULT_JUDGE_CACHE = f"{HOME}/.claude/data/skill-judge-cache.jsonl"
DEFAULT_JUDGE_FAILURES = f"{HOME}/.claude/data/skill-judge-failures"

# Phase 7.7a.1 (2026-05-22) added body-token Jaccard as a 4th signal because the
# Phase 7.7a dogfood revealed description-Jaccard catches lexical/literal overlap
# well (caught 2200+ plugin-cache duplicates) but missed semantic overlap when
# authors use different vocabulary (e.g. humanize-ai-writing ↔ voice-extractor
# scored desc Jaccard=0.138 despite overlapping subject matter). Body tokens are
# extracted via extract_body() and weighted at W_BODY=0.20.


def kill_switch() -> bool:
    return os.environ.get("SKILL_CONSOLIDATE", "on").lower() == "off"


def discover_skills(roots_str: str) -> list[dict]:
    """Walk roots, find SKILL.md, parse frontmatter, annotate source.

    Returns: list of {name, description, source, path}. The caller (main())
    adds `tokens` (description tokens) and `body_tokens` (SKILL.md body tokens
    via extract_body()) after loading STOPWORDS.

    Skipped skills (missing both name+description, or invalid YAML) logged to stderr.
    """
    skills = []
    skipped = 0
    for root in roots_str.split(":"):
        root_path = Path(root)
        if not root_path.exists():
            continue
        for skill_md in root_path.rglob("SKILL.md"):
            meta = _parse_frontmatter(skill_md)
            if meta is None:
                skipped += 1
                continue
            name = meta.get("name", "").strip()
            description = meta.get("description", "").strip()
            if not name and not description:
                skipped += 1
                continue
            source = _classify_source(skill_md, root_path)
            skills.append({
                "name": name or skill_md.parent.name,
                "description": description,
                "source": source,
                "path": str(skill_md),
            })
    print(f"# discovered {len(skills)} skills, skipped {skipped}", file=sys.stderr)
    return skills


def _parse_frontmatter(path: Path) -> dict | None:
    """Read first YAML frontmatter block. Returns dict of top-level scalar fields.

    Hand-rolled (no PyYAML dep). Supports only `key: value` on single lines —
    enough for SKILL.md schemas. Returns None on parse failure.
    """
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    block = text[4:end]
    meta: dict = {}
    for line in block.split("\n"):
        m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2)
            if (val.startswith('"') and val.endswith('"')) or \
               (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            meta[key] = val
    return meta


def _classify_source(skill_md: Path, root: Path) -> str:
    """Return '[user]' or '[plugin:<plugin-name>]' based on path relative to root."""
    try:
        rel = skill_md.relative_to(root)
    except ValueError:
        return "[user]"
    parts = rel.parts
    if "plugin" in str(root).lower() or "cache" in str(root).lower():
        return f"[plugin:{parts[0]}]"
    return "[user]"


def extract_body(skill_md_path: Path) -> str:
    """Read SKILL.md, strip frontmatter + fenced code blocks, return rest.

    Returns empty string on any IO error (soft-fail). Files with no frontmatter
    return full content. Files with only frontmatter return empty string.
    """
    try:
        text = skill_md_path.read_text(encoding="utf-8", errors="replace")
    except (FileNotFoundError, OSError):
        return ""
    text = _FRONTMATTER_RE.sub("", text, count=1)
    text = _FENCED_CODE_RE.sub("", text)
    return text


def _iso_now() -> str:
    """Current UTC time in ISO 8601 format (with colons in time portion)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _cache_key(s1_path: str, s2_path: str) -> str:
    """Order-independent sha256 of (path:body, path:body) for the pair.

    Editing either skill's body invalidates the entry. Swapping s1/s2 produces
    the same key (input list is sorted).
    """
    body_a = extract_body(Path(s1_path))
    body_b = extract_body(Path(s2_path))
    parts = sorted([f"{s1_path}:{body_a}", f"{s2_path}:{body_b}"])
    return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


def _load_judge_cache(cache_path: Path) -> dict:
    """Read JSONL → dict keyed by 'key' field. Skip corrupt lines. Soft-fail on missing file."""
    cache: dict = {}
    if not cache_path.exists():
        return cache
    try:
        with cache_path.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                key = row.get("key")
                if key:
                    cache[key] = row
    except OSError:
        return {}
    return cache


def _append_verdict_locked(cache_path: Path, key: str, s1_name: str, s2_name: str,
                            verdict: dict) -> None:
    """Atomic JSONL append with mkdir-based lock (Phase 7.6 precedent)."""
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    lock_dir = cache_path.with_suffix(cache_path.suffix + ".lock")
    row = {"key": key, "name_a": s1_name, "name_b": s2_name, **verdict}
    line = json.dumps(row, separators=(",", ":")) + "\n"
    for _ in range(20):
        try:
            lock_dir.mkdir()
        except FileExistsError:
            time.sleep(0.05)
            continue
        try:
            with cache_path.open("a", encoding="utf-8") as f:
                f.write(line)
        finally:
            try:
                lock_dir.rmdir()
            except OSError:
                pass
        return
    # Lock contention exhausted — bypass + append anyway (last resort)
    with cache_path.open("a", encoding="utf-8") as f:
        f.write(line)


_JUDGE_PROMPT_TEMPLATE = """You are judging whether two Claude Code skills overlap in purpose enough that one could be deleted in favor of the other.

# Skill A: {name_a}
{body_a}

# Skill B: {name_b}
{body_b}

# Task
Decide if these two skills meaningfully overlap in purpose — would a user pick one OR the other for the same job?

Respond with EXACTLY this JSON shape and nothing else:

{{"overlap": true, "confidence": 4, "rationale": "Both extract a writing voice profile for AI mimicry; methods differ but the outcome is the same artifact."}}

- `overlap`: literal `true` or `false`. Not "yes"/"no".
- `confidence`: integer literal 1, 2, 3, 4, or 5. (1=guess, 5=certain)
- `rationale`: under 50 words. One sentence.

No prose before or after the JSON. No markdown fences. No prefix like "Answer:".
"""


def _build_judge_prompt(name_a: str, body_a: str, name_b: str, body_b: str) -> str:
    return _JUDGE_PROMPT_TEMPLATE.format(
        name_a=name_a, body_a=body_a, name_b=name_b, body_b=body_b,
    )


_FENCE_RE = re.compile(r"^\s*```(?:json)?\s*\n?(.*?)\n?\s*```\s*$", re.DOTALL)


def _strip_fences(text: str) -> str:
    """Strip markdown code fences (```json...``` or plain ```...```)."""
    m = _FENCE_RE.match(text.strip())
    return m.group(1) if m else text.strip()


def _parse_judge_response(stdout: str) -> dict | None:
    """Returns parsed verdict dict on success; None on parse or schema failure.

    Handles two stdout shapes:
    1. `claude -p --output-format json` envelope: {"type":"result","result":"<inner>",...}
       where `<inner>` may itself be markdown-fenced JSON.
    2. Raw verdict JSON (test mocks echo this directly).
    """
    text = stdout.strip()
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(parsed, dict):
        return None
    # Envelope shape: extract `result` field and re-parse its (possibly fenced) content
    if "result" in parsed and isinstance(parsed["result"], str) and "overlap" not in parsed:
        inner_text = _strip_fences(parsed["result"])
        try:
            data = json.loads(inner_text)
        except json.JSONDecodeError:
            return None
        if not isinstance(data, dict):
            return None
    else:
        data = parsed
    overlap = data.get("overlap")
    confidence = data.get("confidence")
    rationale = data.get("rationale", "")
    if not isinstance(overlap, bool):
        return None
    if not isinstance(confidence, int) or confidence < 1 or confidence > 5:
        return None
    if not isinstance(rationale, str):
        return None
    return {"overlap": overlap, "confidence": confidence,
            "rationale": rationale[:JUDGE_RATIONALE_MAX]}


def _snapshot_failure(s1_path: str, s2_path: str, s1_name: str, s2_name: str,
                      stdout: str, stderr: str) -> None:
    """Write parse-failure snapshot to JUDGE_FAILURE_DIR. Soft-fail on IO error."""
    failure_dir = Path(os.environ.get("JUDGE_FAILURE_DIR", DEFAULT_JUDGE_FAILURES))
    try:
        failure_dir.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
        key_short = _cache_key(s1_path, s2_path)[:12]
        path = failure_dir / f"{ts}-{key_short}.json"
        path.write_text(json.dumps({
            "name_a": s1_name, "name_b": s2_name,
            "stdout": stdout[:8000], "stderr": stderr[:4000],
        }, indent=2), encoding="utf-8")
    except OSError:
        pass


_JUDGE_SYSTEM_PROMPT = (
    "You evaluate whether two software components overlap in purpose. "
    "Respond with only JSON matching the requested schema."
)

_JUDGE_JSON_SCHEMA = (
    '{"type":"object","properties":{'
    '"overlap":{"type":"boolean"},'
    '"confidence":{"type":"integer","minimum":1,"maximum":5},'
    '"rationale":{"type":"string"}'
    '},"required":["overlap","confidence","rationale"]}'
)


def judge_pair(s1: dict, s2: dict) -> dict:
    """Single-pair LLM judge invocation. Retry once on bad JSON; snapshot on 2nd failure.

    Uses `claude --bare -p` to skip CLAUDE.md/skills/hooks context (~105k tokens otherwise).
    Output is an envelope `{"type":"result", "result":"...", ...}`; the model's actual
    response is the string in `result`, which may be markdown-fenced JSON.

    Returns: {overlap, confidence, rationale, judge_status, ts, model}.
    judge_status in {'ok', 'parse_failed', 'timeout'}.
    """
    body_a = extract_body(Path(s1["path"]))[:JUDGE_BODY_TRUNC]
    body_b = extract_body(Path(s2["path"]))[:JUDGE_BODY_TRUNC]
    prompt = _build_judge_prompt(s1["name"], body_a, s2["name"], body_b)
    claude_cmd = os.environ.get("JUDGE_CLAUDE_CMD", "claude")
    # Production invocation uses --bare to bypass workspace context overhead.
    # Tests inject JUDGE_CLAUDE_CMD pointing at a bash mock that ignores args
    # and echoes a canned response, so flags are no-ops in test mode.
    cmd = [
        claude_cmd, "--bare", "-p",
        "--model", JUDGE_MODEL,
        "--output-format", "json",
        "--no-session-persistence",
        "--system-prompt", _JUDGE_SYSTEM_PROMPT,
        "--json-schema", _JUDGE_JSON_SCHEMA,
        prompt,
    ]
    base = {"ts": _iso_now(), "model": JUDGE_MODEL}
    last_stdout = ""
    last_stderr = ""
    for _attempt in (1, 2):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True,
                                    timeout=JUDGE_TIMEOUT_S, check=False)
        except subprocess.TimeoutExpired:
            return {**base, "judge_status": "timeout"}
        except FileNotFoundError:
            return {**base, "judge_status": "parse_failed"}
        last_stdout = result.stdout
        last_stderr = result.stderr
        verdict = _parse_judge_response(result.stdout)
        if verdict is not None:
            return {**base, **verdict, "judge_status": "ok"}
    _snapshot_failure(s1["path"], s2["path"], s1["name"], s2["name"],
                      last_stdout, last_stderr)
    return {**base, "judge_status": "parse_failed"}


def judge_layer(ambiguity_band: list[dict], cache_path: Path) -> tuple[dict, dict]:
    """Orchestrate cache lookup + parallel-worker judging.

    Returns (verdicts, stats):
      verdicts: dict[(name_a, name_b)] -> verdict_dict
      stats: {total, cache_hits, fresh_judged, parse_failed, timed_out, capped}
    """
    cache = _load_judge_cache(cache_path)
    verdicts: dict = {}
    queue = []
    stats = {"total": 0, "cache_hits": 0, "fresh_judged": 0,
             "parse_failed": 0, "timed_out": 0, "capped": 0}

    sorted_band = sorted(ambiguity_band, key=lambda p: -p["composite"])
    if len(sorted_band) > JUDGE_MAX_PAIRS:
        stats["capped"] = len(sorted_band) - JUDGE_MAX_PAIRS
        print(f"# judge: ambiguity_band has {len(sorted_band)} pairs; "
              f"capping at top {JUDGE_MAX_PAIRS}", file=sys.stderr)
        sorted_band = sorted_band[:JUDGE_MAX_PAIRS]
    stats["total"] = len(sorted_band)

    for p in sorted_band:
        s1, s2 = p["s1"], p["s2"]
        key = _cache_key(s1["path"], s2["path"])
        if key in cache:
            verdicts[(s1["name"], s2["name"])] = cache[key]
            stats["cache_hits"] += 1
        else:
            queue.append((key, s1, s2))

    if not queue:
        return verdicts, stats

    print(f"# judge: {len(queue)} pairs to judge fresh "
          f"(cap {JUDGE_MAX_PAIRS}, wall {JUDGE_WALL_S}s, workers {JUDGE_WORKERS})",
          file=sys.stderr)

    pool = ThreadPoolExecutor(max_workers=JUDGE_WORKERS)
    try:
        futures = {pool.submit(judge_pair, s1, s2): (key, s1, s2)
                   for key, s1, s2 in queue}
        try:
            for fut in as_completed(futures, timeout=JUDGE_WALL_S):
                key, s1, s2 = futures[fut]
                try:
                    verdict = fut.result()
                except Exception as e:
                    verdict = {"judge_status": "parse_failed",
                               "ts": _iso_now(), "model": JUDGE_MODEL,
                               "error": str(e)[:200]}
                verdicts[(s1["name"], s2["name"])] = verdict
                status = verdict.get("judge_status", "parse_failed")
                if status == "ok":
                    stats["fresh_judged"] += 1
                    _append_verdict_locked(cache_path, key, s1["name"], s2["name"], verdict)
                elif status == "parse_failed":
                    stats["parse_failed"] += 1
                elif status == "timeout":
                    stats["timed_out"] += 1
        except TimeoutError:
            print(f"# judge: hit {JUDGE_WALL_S}s wall budget; "
                  f"cancelling in-flight workers", file=sys.stderr)
    finally:
        pool.shutdown(wait=False, cancel_futures=True)

    return verdicts, stats


def load_stopwords() -> set[str]:
    """Regex-parse STOPWORDS line from skills-prefilter.sh. Single source of truth.

    Falls back to empty set + stderr warning if file/line missing or malformed.
    """
    try:
        text = Path(STOPWORDS_SOURCE).read_text(encoding="utf-8", errors="replace")
    except OSError:
        print(f"# warning: STOPWORDS source missing at {STOPWORDS_SOURCE}", file=sys.stderr)
        return set()
    m = re.search(r'^STOPWORDS="([^"]*)"', text, re.MULTILINE)
    if not m:
        print(f"# warning: STOPWORDS line not found in {STOPWORDS_SOURCE}", file=sys.stderr)
        return set()
    return set(m.group(1).split())


def tokenize(text: str, stopwords: set[str]) -> set[str]:
    """Lowercase, extract alphabetic tokens, drop stopwords."""
    tokens = re.findall(r"[a-z]+", text.lower())
    return {t for t in tokens if t not in stopwords}


def jaccard(a: set[str], b: set[str]) -> float:
    """|A∩B| / |A∪B|. Returns 0.0 for two empty sets (avoids divide-by-zero)."""
    if not a and not b:
        return 0.0
    return len(a & b) / len(a | b)


def load_bake_off_losses(log_path: str) -> dict[str, set[str]]:
    """Read bake-off-log.jsonl. Build map: skill_name -> set of run_ids where it lost.

    Returns empty dict if file missing/malformed (soft-fail).
    Schema per scripts/bake-off-record.sh:
      {"run_id": "...", "winner": "name", "losers": ["name1", "name2"]}
    """
    losses: dict[str, set[str]] = {}
    p = Path(log_path)
    if not p.exists():
        return losses
    try:
        with p.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                run_id = row.get("run_id")
                if not run_id:
                    continue
                for loser in row.get("losers", []) or []:
                    losses.setdefault(loser, set()).add(run_id)
    except OSError:
        return {}
    return losses


def shared_losses(a: str, b: str, losses: dict[str, set[str]]) -> int:
    return len(losses.get(a, set()) & losses.get(b, set()))


def load_eliminated(stats_path: str) -> set[str]:
    """Read bake-off-stats.tsv. Return set of eliminated skill names.

    Schema: skill\\tappearances\\twins\\tlosses\\tlast_run_iso (with header row)
    Eliminated = appearances >= 3 AND wins == 0.
    Soft-fails: returns empty set if file missing/malformed.
    """
    eliminated: set[str] = set()
    p = Path(stats_path)
    if not p.exists():
        return eliminated
    try:
        with p.open(encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i == 0 and line.startswith("skill\t"):
                    continue
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 3:
                    continue
                try:
                    name = parts[0]
                    appearances = int(parts[1])
                    wins = int(parts[2])
                except (ValueError, IndexError):
                    continue
                if appearances >= 3 and wins == 0:
                    eliminated.add(name)
    except OSError:
        return set()
    return eliminated


def composite_score(desc_j: float, body_j: float, losses_n: int, elim_n: int,
                    jaccard_only: bool = False) -> float:
    """Weighted sum across 4 signals.

    Full mode: W_DESC * desc_j + W_BODY * body_j + W_LOSSES * losses_norm + W_ELIM * elim_norm.
    Jaccard-only fallback: (W_DESC * desc_j + W_BODY * body_j) / (W_DESC + W_BODY).
    Rescale keeps Jaccard-only scores comparable to full-mode tier cuts.
    """
    if jaccard_only:
        return (W_DESC * desc_j + W_BODY * body_j) / (W_DESC + W_BODY)
    losses_norm = min(losses_n / LOSSES_CAP, 1.0)
    elim_norm = 1.0 if elim_n else 0.0
    return W_DESC * desc_j + W_BODY * body_j + W_LOSSES * losses_norm + W_ELIM * elim_norm


def _is_plugin_plugin(s1: dict, s2: dict) -> bool:
    return s1["source"].startswith("[plugin:") and s2["source"].startswith("[plugin:")


def assign_tier(composite: float, source_a: str, source_b: str) -> str:
    """HIGH / MEDIUM / LOW / DROP.

    Plugin+plugin pairs that would otherwise be HIGH/MEDIUM are demoted to LOW
    (no actionable verb). Noise floor (< 0.15) applies universally — including
    plugin+plugin — pairs below threshold are dropped from the report entirely.
    Ref: feedback_tier_demotion_is_not_noise_floor_bypass.md.
    """
    if composite < TIER_LOW:
        return "DROP"
    plugin_plugin = source_a.startswith("[plugin:") and source_b.startswith("[plugin:")
    if plugin_plugin:
        return "LOW"
    if composite >= TIER_HIGH:
        return "HIGH"
    if composite >= TIER_MEDIUM:
        return "MEDIUM"
    return "LOW"


def pick_winner(s_a: dict, s_b: dict, wins_map: dict[str, int],
                appearances_map: dict[str, int]) -> tuple[str, str]:
    """Return (winner_name, loser_name). Tiebreaks: bake-off wins > appearances > alphabetical."""
    a_wins = wins_map.get(s_a["name"], 0)
    b_wins = wins_map.get(s_b["name"], 0)
    if a_wins != b_wins:
        return (s_a["name"], s_b["name"]) if a_wins > b_wins else (s_b["name"], s_a["name"])
    a_app = appearances_map.get(s_a["name"], 0)
    b_app = appearances_map.get(s_b["name"], 0)
    if a_app != b_app:
        return (s_a["name"], s_b["name"]) if a_app > b_app else (s_b["name"], s_a["name"])
    return (s_a["name"], s_b["name"]) if s_a["name"] < s_b["name"] else (s_b["name"], s_a["name"])


def derive_verb(s_a: dict, s_b: dict, tier: str,
                wins_map: dict[str, int], appearances_map: dict[str, int]) -> str:
    """Recommendation verb per spec § Recommendation verb table. LOW returns 'informational only'."""
    if tier == "LOW":
        return "informational only"
    src_a, src_b = s_a["source"], s_b["source"]
    if src_a == "[user]" and src_b == "[user]":
        winner, loser = pick_winner(s_a, s_b, wins_map, appearances_map)
        return f"merge: keep `{winner}`, delete `{loser}`"
    if src_a == "[user]" and src_b.startswith("[plugin:"):
        return _user_plugin_verb(s_a, s_b, wins_map)
    if src_b == "[user]" and src_a.startswith("[plugin:"):
        return _user_plugin_verb(s_b, s_a, wins_map)
    return "informational only"


def _user_plugin_verb(user_s: dict, plugin_s: dict, wins_map: dict[str, int]) -> str:
    u_wins = wins_map.get(user_s["name"], 0)
    p_wins = wins_map.get(plugin_s["name"], 0)
    if u_wins > p_wins:
        return f"keep user `{user_s['name']}` (override of plugin `{plugin_s['name']}`)"
    return f"delete user-installed `{user_s['name']}` (plugin `{plugin_s['name']}` wins or ties)"


def _score_all_pairs(sorted_skills: list[dict], losses_map: dict, eliminated_set: set,
                     wins_map: dict, appearances_map: dict,
                     jaccard_only_mode: bool) -> dict[str, list[dict]]:
    """Score every ordered pair of skills and bucket by tier.

    Returns pairs_by_tier dict with keys HIGH/MEDIUM/LOW, each holding a list of
    pair dicts. DROPped pairs are silently omitted — the caller never sees them.
    Does not mutate the input collections themselves; pair dicts hold references
    to skill dicts from sorted_skills, so callers must not mutate those in place.
    """
    pairs_by_tier: dict[str, list[dict]] = {"HIGH": [], "MEDIUM": [], "LOW": []}
    for i in range(len(sorted_skills)):
        for j in range(i + 1, len(sorted_skills)):
            s1, s2 = sorted_skills[i], sorted_skills[j]
            desc_j = jaccard(s1["tokens"], s2["tokens"])
            body_j = jaccard(s1["body_tokens"], s2["body_tokens"])
            losses_n = shared_losses(s1["name"], s2["name"], losses_map)
            elim_n = 1 if (s1["name"] in eliminated_set or s2["name"] in eliminated_set) else 0
            comp = composite_score(desc_j, body_j, losses_n, elim_n, jaccard_only=jaccard_only_mode)
            tier = assign_tier(comp, s1["source"], s2["source"])
            if tier == "DROP":
                continue
            verb = derive_verb(s1, s2, tier, wins_map, appearances_map)
            pairs_by_tier[tier].append({
                "s1": s1, "s2": s2,
                "desc_jaccard": desc_j, "body_jaccard": body_j,
                "losses": losses_n, "elim": elim_n,
                "composite": comp, "verb": verb,
            })
    return pairs_by_tier


def _collect_ambiguity_band(pairs_by_tier: dict[str, list[dict]]) -> list[dict]:
    """Gather pairs in the judge's ambiguity range [AMBIGUITY_LO, AMBIGUITY_HI).

    Plugin+plugin pairs are excluded because the judge layer only runs on
    user-owned skills where an actionable recommendation can be made.
    """
    # Phase 7.7a.2 — collect ambiguity band for judge layer
    band = []
    for tier_name in ("HIGH", "MEDIUM", "LOW"):
        for p in pairs_by_tier[tier_name]:
            if (JUDGE_AMBIGUITY_LO <= p["composite"] < JUDGE_AMBIGUITY_HI
                    and not _is_plugin_plugin(p["s1"], p["s2"])):
                band.append(p)
    return band


def _run_judge_layer(ambiguity_band: list[dict]) -> tuple[dict, dict | None]:
    """Invoke judge_layer unless kill switch or --no-judge flag is set.

    Returns ({}, None) when judging is skipped (kill switch, --no-judge flag,
    or empty band). Returns (verdicts_dict, stats_dict) from judge_layer otherwise.
    Reads sys.argv for the --no-judge flag.
    """
    # Phase 7.7a.2 — judge layer (skipped if kill switch or --no-judge)
    judge_off = os.environ.get("SKILL_JUDGE", "on").lower() == "off"
    no_judge_flag = "--no-judge" in sys.argv
    if judge_off or no_judge_flag or not ambiguity_band:
        return {}, None
    cache_path = Path(os.environ.get("JUDGE_CACHE_FILE", DEFAULT_JUDGE_CACHE))
    return judge_layer(ambiguity_band, cache_path)


def _assemble_semantic_tier(ambiguity_band: list[dict], judge_verdicts: dict,
                            pairs_by_tier: dict[str, list[dict]]) -> tuple[list[dict], int]:
    """Promote judge-confirmed overlaps into the SEMANTIC tier.

    Returns (capped_semantic_pairs, total_before_cap). Pairs that meet the
    confidence floor are annotated with judge metadata and sorted
    (confidence desc, composite desc) before the tier cap is applied.

    PRECONDITION: must be called before TIER_CAP truncation — the orig_tier
    lookup reads pairs_by_tier membership, which is lost once lists are sliced.
    """
    # Phase 7.7a.2 — assemble SEMANTIC tier
    semantic_pairs: list[dict] = []
    if judge_verdicts:
        for p in ambiguity_band:
            key = (p["s1"]["name"], p["s2"]["name"])
            v = judge_verdicts.get(key, {})
            if v.get("overlap") is True and v.get("confidence", 0) >= JUDGE_CONFIDENCE_FLOOR:
                # Find original tier for the cross-reference annotation
                orig_tier = "LOW"
                for tn in ("HIGH", "MEDIUM", "LOW"):
                    if p in pairs_by_tier[tn]:
                        orig_tier = tn
                        break
                semantic_pairs.append({**p,
                                       "judge_confidence": v["confidence"],
                                       "judge_rationale": v.get("rationale", ""),
                                       "orig_tier": orig_tier})
    semantic_pairs.sort(key=lambda x: (-x["judge_confidence"], -x["composite"]))
    semantic_total = len(semantic_pairs)
    return semantic_pairs[:JUDGE_TIER_CAP], semantic_total


def _render_semantic_section(semantic_pairs: list[dict], semantic_total: int) -> list[str]:
    """Render the SEMANTIC tier as markdown lines (with trailing blank line per entry).

    Returns an empty list when there are no SEMANTIC pairs — caller skips the block.
    """
    if not semantic_pairs:
        return []
    lines = []
    shown = len(semantic_pairs)
    suffix = (f" (showing top {shown} of {semantic_total})"
              if semantic_total > shown else f" ({semantic_total} pairs)")
    lines.append(f"## SEMANTIC{suffix}")
    lines.append("")
    for p in semantic_pairs:
        short_rat = (p["judge_rationale"][:80] + "…"
                     if len(p["judge_rationale"]) > 80 else p["judge_rationale"])
        lines.append(f"### `{p['s1']['name']}` {p['s1']['source']}"
                     f"  ↔  `{p['s2']['name']}` {p['s2']['source']}")
        lines.append(f"**Judge:** overlap=true, confidence={p['judge_confidence']}/5 — _{short_rat}_")
        lines.append(f"**Composite:** {p['composite']:.3f} (also in {p['orig_tier']}) — "
                     f"`desc_jaccard={p['desc_jaccard']:.3f}, "
                     f"body_jaccard={p['body_jaccard']:.3f}`")
        lines.append(f"**Verb:** {p['verb']}")
        lines.append("")
    return lines


def _render_tier_section(tier: str, pairs: list[dict], total: int) -> list[str]:
    """Render one Jaccard tier (HIGH / MEDIUM / LOW) as markdown lines.

    Each pair entry ends with a blank line; the section header is always emitted
    even when the tier is empty, so the report structure is stable across runs.
    """
    lines = []
    shown = len(pairs)
    suffix = f" (showing top {shown} of {total})" if total > shown else f" ({total} pairs)"
    lines.append(f"## {tier}{suffix}")
    lines.append("")
    if not pairs:
        lines.append("_None._")
        lines.append("")
        return lines
    for p in pairs:
        lines.append(f"### `{p['s1']['name']}` {p['s1']['source']}  ↔  `{p['s2']['name']}` {p['s2']['source']}")
        lines.append(f"**Composite:** {p['composite']:.3f} — `desc_jaccard={p['desc_jaccard']:.3f}, body_jaccard={p['body_jaccard']:.3f}, losses={p['losses']}, eliminated={'Y' if p['elim'] else 'N'}`")
        lines.append(f"**Verb:** {p['verb']}")
        lines.append("")
    return lines


def _render_footer(skills: list[dict], losses_map: dict, eliminated_set: set,
                   judge_stats: dict | None) -> list[str]:
    """Render the report footer: signal availability, weights, optional judge stats.

    judge_stats is None when judging was skipped; the footer line is omitted in that case.
    """
    bake_off_count = sum(1 for s in skills if s["name"] in losses_map)
    coverage_pct = (bake_off_count / len(skills) * 100) if skills else 0
    low_cov_warning = ("⚠ low bake-off coverage — composite scores heavily Jaccard-weighted\n\n"
                       if coverage_pct < 10 else "")
    footer_lines = [
        "---",
        "",
        low_cov_warning + "**Signal availability**",
        f"- description tokens: {len(skills)} skills",
        f"- bake-off history: {bake_off_count} skills ({coverage_pct:.1f}%)",
        f"- eliminated: {len(eliminated_set)} skills",
        "",
        f"**Source weights:** desc={W_DESC}, body={W_BODY}, losses={W_LOSSES}, elim={W_ELIM}",
    ]
    if judge_stats is not None:
        footer_lines.append(
            f"**Judge:** judged={judge_stats['total']} pairs "
            f"(cache_hits={judge_stats['cache_hits']}, "
            f"fresh={judge_stats['fresh_judged']}, "
            f"parse_failed={judge_stats['parse_failed']}, "
            f"timed_out={judge_stats['timed_out']}); "
            f"model={JUDGE_MODEL}; caps={JUDGE_MAX_PAIRS}pairs/{JUDGE_WALL_S}s"
        )
    footer_lines.extend([
        f"**Stoplist version:** phase-7-2-3 (sourced from `scripts/skills-prefilter.sh`)",
        f"**Generated:** {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
        "",
    ])
    return footer_lines


def build_report(skills: list[dict], losses_map: dict, eliminated_set: set,
                 wins_map: dict, appearances_map: dict,
                 jaccard_only_mode: bool) -> str:
    """Build the full markdown report. Returns the report text.

    Delegates each logical phase to a focused helper so each concern stays within
    the 50-line guideline. This function is an orchestrator only — no scoring or
    rendering logic lives here.
    """
    sorted_skills = sorted(skills, key=lambda s: s["name"])

    pairs_by_tier = _score_all_pairs(
        sorted_skills, losses_map, eliminated_set, wins_map, appearances_map, jaccard_only_mode,
    )

    ambiguity_band = _collect_ambiguity_band(pairs_by_tier)
    judge_verdicts, judge_stats = _run_judge_layer(ambiguity_band)
    semantic_pairs, semantic_total = _assemble_semantic_tier(
        ambiguity_band, judge_verdicts, pairs_by_tier,
    )

    # Cap each Jaccard tier to TIER_CAP before rendering (totals saved first for suffix)
    tier_total = {tier: len(pairs) for tier, pairs in pairs_by_tier.items()}
    for tier in pairs_by_tier:
        pairs_by_tier[tier].sort(key=lambda p: -p["composite"])
        pairs_by_tier[tier] = pairs_by_tier[tier][:TIER_CAP]

    lines: list[str] = ["# Skill Consolidation Report", ""]
    if jaccard_only_mode:
        lines.append("⚠ **Jaccard-only mode** — bake-off data unavailable. Composite scores collapse to Jaccard.")
        lines.append("")

    lines.extend(_render_semantic_section(semantic_pairs, semantic_total))

    for tier in ["HIGH", "MEDIUM", "LOW"]:
        lines.extend(_render_tier_section(tier, pairs_by_tier[tier], tier_total[tier]))

    lines.extend(_render_footer(skills, losses_map, eliminated_set, judge_stats))

    return "\n".join(lines)


def write_report(report_text: str, report_dir: str) -> str:
    """Write report to ISO-stamped file. Falls back to stdout if dir not writable."""
    p = Path(report_dir)
    try:
        p.mkdir(parents=True, exist_ok=True)
    except OSError:
        print(report_text)
        return "<stdout — report dir not writable>"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    out_path = p / f"{ts}.md"
    try:
        out_path.write_text(report_text, encoding="utf-8")
    except OSError:
        print(report_text)
        return "<stdout — write failed>"
    return str(out_path)


def load_wins_appearances(stats_path: str) -> tuple[dict, dict]:
    """Return (wins_map, appearances_map). Empty maps on missing file."""
    wins: dict[str, int] = {}
    apps: dict[str, int] = {}
    p = Path(stats_path)
    if not p.exists():
        return wins, apps
    try:
        with p.open(encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i == 0 and line.startswith("skill\t"):
                    continue
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 3:
                    continue
                try:
                    apps[parts[0]] = int(parts[1])
                    wins[parts[0]] = int(parts[2])
                except (ValueError, IndexError):
                    continue
    except OSError:
        return {}, {}
    return wins, apps


def main() -> int:
    if kill_switch():
        print("# /consolidate-skills disabled (SKILL_CONSOLIDATE=off)")
        return 0

    # Function-level debug modes — don't need a populated corpus
    if "--extract-body" in sys.argv:
        idx = sys.argv.index("--extract-body")
        if idx + 1 >= len(sys.argv):
            print("# usage: --extract-body <path-to-SKILL.md>", file=sys.stderr)
            return 2
        print(extract_body(Path(sys.argv[idx + 1])))
        return 0

    if "--composite-test" in sys.argv:
        line = sys.stdin.readline().strip()
        parts = line.split("|")
        if len(parts) < 5:
            print("# usage: echo 'desc_j|body_j|losses_n|elim_n|jaccard_only' | --composite-test", file=sys.stderr)
            return 2
        try:
            desc_j = float(parts[0])
            body_j = float(parts[1])
            losses_n = int(parts[2])
            elim_n = int(parts[3])
            jaccard_only = parts[4].strip().lower() in ("true", "1", "yes")
        except (ValueError, IndexError):
            print("# parse error", file=sys.stderr)
            return 2
        score = composite_score(desc_j, body_j, losses_n, elim_n, jaccard_only=jaccard_only)
        print(f"{score:.3f}")
        return 0

    if "--cache-key" in sys.argv:
        idx = sys.argv.index("--cache-key")
        if idx + 2 >= len(sys.argv):
            print("# usage: --cache-key <pathA> <pathB>", file=sys.stderr)
            return 2
        print(_cache_key(sys.argv[idx + 1], sys.argv[idx + 2]))
        return 0

    if "--cache-dump" in sys.argv:
        cache_path = Path(os.environ.get("JUDGE_CACHE_FILE", DEFAULT_JUDGE_CACHE))
        cache = _load_judge_cache(cache_path)
        for key, row in cache.items():
            print(json.dumps(row, separators=(",", ":")))
        return 0

    if "--judge-pair" in sys.argv:
        idx = sys.argv.index("--judge-pair")
        if idx + 2 >= len(sys.argv):
            print("# usage: --judge-pair <pathA> <pathB>", file=sys.stderr)
            return 2
        path_a = sys.argv[idx + 1]
        path_b = sys.argv[idx + 2]
        # Build minimal skill dicts (judge_pair needs name + path)
        s1 = {"name": Path(path_a).parent.name, "path": path_a}
        s2 = {"name": Path(path_b).parent.name, "path": path_b}
        verdict = judge_pair(s1, s2)
        print(json.dumps(verdict, indent=2))
        return 0

    roots = os.environ.get("SKILL_CONSOLIDATE_ROOTS", DEFAULT_ROOTS)
    skills = discover_skills(roots)

    if "--discover-only" in sys.argv:
        for s in skills:
            print(f"{s['name']} | {s['source']}")
        return 0

    if not skills:
        print(f"# no skills found at {roots}")
        return 0

    stopwords = load_stopwords()
    for s in skills:
        s["tokens"] = tokenize(s["description"], stopwords)
        s["body_tokens"] = tokenize(extract_body(Path(s["path"])), stopwords)

    if "--jaccard-only" in sys.argv:
        sorted_skills = sorted(skills, key=lambda s: s["name"])
        for i in range(len(sorted_skills)):
            for j in range(i + 1, len(sorted_skills)):
                s1, s2 = sorted_skills[i], sorted_skills[j]
                desc_j = jaccard(s1["tokens"], s2["tokens"])
                body_j = jaccard(s1["body_tokens"], s2["body_tokens"])
                print(f"{s1['name']} | {s2['name']} | {desc_j:.3f} | {body_j:.3f}")
        return 0

    bake_off_log = os.environ.get("BAKEOFF_LOG_FILE", DEFAULT_LOG)
    losses_map = load_bake_off_losses(bake_off_log)
    bake_off_available = bool(losses_map)

    bake_off_stats = os.environ.get("BAKEOFF_STATS_FILE", DEFAULT_STATS)
    eliminated_set = load_eliminated(bake_off_stats)
    elim_available = bool(eliminated_set)

    # --tier-from-stdin: boundary-test mode. Reads "skillA|skillB|composite" lines,
    # prints "skillA|skillB|composite|tier". Uses placeholder [user] sources.
    if "--tier-from-stdin" in sys.argv:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            parts = line.split("|")
            if len(parts) < 3:
                continue
            try:
                c = float(parts[2])
            except ValueError:
                continue
            tier = assign_tier(c, "[user]", "[user]")
            print(f"{parts[0]}|{parts[1]}|{parts[2]}|{tier}")
        return 0

    if "--score-only" in sys.argv:
        sorted_skills = sorted(skills, key=lambda s: s["name"])
        for i in range(len(sorted_skills)):
            for j in range(i + 1, len(sorted_skills)):
                s1, s2 = sorted_skills[i], sorted_skills[j]
                desc_j = jaccard(s1["tokens"], s2["tokens"])
                body_j = jaccard(s1["body_tokens"], s2["body_tokens"])
                losses_n = shared_losses(s1["name"], s2["name"], losses_map)
                elim_n = 1 if (s1["name"] in eliminated_set or s2["name"] in eliminated_set) else 0
                # --score-only is a debug helper; column 7 is a placeholder (no composite computed in this path)
                print(f"{s1['name']} | {s2['name']} | {desc_j:.3f} | {body_j:.3f} | {losses_n} | {elim_n} | 0.000")
        return 0

    wins_map, appearances_map = load_wins_appearances(bake_off_stats)
    jaccard_only_mode = not bake_off_available and not elim_available

    report = build_report(skills, losses_map, eliminated_set,
                          wins_map, appearances_map, jaccard_only_mode)
    report_dir = os.environ.get("REPORT_DIR", DEFAULT_REPORT_DIR)
    out_path = write_report(report, report_dir)
    print(f"# Report written to: {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
