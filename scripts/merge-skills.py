#!/usr/bin/env python3
"""
/merge-skills — synthesize two overlapping SKILL.md files into a single merged draft.

Phase 7.7a.4. See ~/github/docs/superpowers/specs/2026-05-22-phase-7-7a-4-merge-skills-design.md.

Env vars (all optional):
- MERGE_SKILLS=off              — kill switch; exit 0 without synthesis
- MERGE_CLAUDE_CMD=<path>       — override `claude` binary (test mocking)
- MERGE_DRAFTS_ROOT=<dir>       — override drafts root (test isolation)
- MERGE_SKILLS_ROOT=<dir>       — override production skills root (test-only)

Exit codes:
  0 — success (or kill switch / garbage-output fallback)
  1 — recoverable failure (synthesis failed, empty output, draft exists)
  2 — invalid args (bad path, fewer than 2 args)
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

HOME = os.path.expanduser("~")
MERGE_MODEL = "claude-sonnet-4-6"
MERGE_TIMEOUT_S = int(os.environ.get("MERGE_TIMEOUT_S", "120"))
MERGE_BODY_TRUNC = 12000
DRAFTS_ROOT_DEFAULT = f"{HOME}/.claude/skills/_drafts"
SKILLS_ROOT_DEFAULT = f"{HOME}/.claude/skills"

_MERGE_SYSTEM_PROMPT = (
    "You synthesize two Claude Code skills into one merged skill. "
    "Output complete SKILL.md content (frontmatter + body). No fences, no prose."
)

_MERGE_PROMPT_TEMPLATE = """You merge two Claude Code skills into one. Both skills overlap in purpose.
Synthesize a single SKILL.md that preserves the best of both.

# Skill A: {name_a}
{content_a}

# Skill B: {name_b}
{content_b}

# Output requirements
Respond with EXACTLY a complete SKILL.md file — frontmatter + body. No prose
before or after. No markdown fences.

Frontmatter MUST include:
- `name`: kebab-case (you propose this — can be either original name or a new name)
- `description`: one paragraph synthesizing both, mentioning all key trigger phrases
- `triggers`: union of both skills' triggers, deduplicated
- `allowed-tools`: union of both skills' allowed-tools

Body MUST:
- Preserve unique sections from each skill (don't drop content)
- Deduplicate shared sections (one canonical version per topic)
- Maintain the same voice/tone as the originals
- Keep length proportional to original lengths (don't expand or compress dramatically)

The user will review your draft before accepting. Be thorough.
"""


def drafts_root() -> Path:
    return Path(os.environ.get("MERGE_DRAFTS_ROOT", DRAFTS_ROOT_DEFAULT))


def skills_root() -> Path:
    return Path(os.environ.get("MERGE_SKILLS_ROOT", SKILLS_ROOT_DEFAULT))


def read_skill(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def _build_synthesis_prompt(name_a: str, content_a: str, name_b: str, content_b: str) -> str:
    return _MERGE_PROMPT_TEMPLATE.format(
        name_a=name_a, content_a=content_a, name_b=name_b, content_b=content_b
    )


_NAME_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
_NAME_FIELD_RE = re.compile(r"^name:\s*([a-z0-9][a-z0-9-]*)\s*$", re.MULTILINE | re.IGNORECASE)


def _parse_proposed_name(text: str) -> str | None:
    """Extract `name:` from frontmatter. Returns None if no valid frontmatter found."""
    fm_match = _NAME_FRONTMATTER_RE.match(text)
    if not fm_match:
        return None
    name_match = _NAME_FIELD_RE.search(fm_match.group(1))
    if not name_match:
        return None
    return name_match.group(1).lower()


def _sanitize_name(raw_name: str | None, fallback_a: str, fallback_b: str) -> str:
    """Sanitize + collision-check. Returns final draft dir name."""
    name = raw_name or f"merged-{fallback_a}-{fallback_b}"
    # Lowercase + kebab-case
    name = re.sub(r"[^a-z0-9-]", "-", name.lower())
    name = re.sub(r"-+", "-", name).strip("-") or f"merged-{fallback_a}-{fallback_b}"
    # Collision with existing production skill → append suffix
    if (skills_root() / name).is_dir():
        name = f"{name}-merged"
    return name


def invoke_synthesizer(prompt: str) -> tuple[str, str]:
    """Returns (stdout, error_msg). Empty error_msg on success."""
    claude_cmd = os.environ.get("MERGE_CLAUDE_CMD", "claude")
    cmd = [
        claude_cmd, "--bare", "-p",
        "--model", MERGE_MODEL,
        "--output-format", "text",
        "--no-session-persistence",
        "--system-prompt", _MERGE_SYSTEM_PROMPT,
        prompt,
    ]
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=MERGE_TIMEOUT_S, check=False,
        )
    except subprocess.TimeoutExpired:
        return "", f"timeout after {MERGE_TIMEOUT_S}s"
    except FileNotFoundError:
        return "", f"command not found: {claude_cmd}"
    if result.returncode != 0:
        return result.stdout or "", (
            f"exit {result.returncode}: {result.stderr.strip()[:200]}"
        )
    return result.stdout, ""


def write_draft(content: str, name: str) -> Path:
    draft_dir = drafts_root() / name
    if draft_dir.exists():
        raise FileExistsError(
            f"draft already exists at {draft_dir} — rm or rename before retrying"
        )
    draft_dir.mkdir(parents=True, exist_ok=False)
    draft_path = draft_dir / "SKILL.md"
    draft_path.write_text(content, encoding="utf-8")
    return draft_path


def print_diffs(path_a: Path, path_b: Path, draft_path: Path) -> None:
    for label, path in (("Skill A", path_a), ("Skill B", path_b)):
        print(f"## diff vs {label}: {path}", file=sys.stderr)
        result = subprocess.run(
            ["diff", "-u", str(path), str(draft_path)],
            capture_output=True, text=True, check=False,
        )
        print(result.stdout, file=sys.stderr)


def main() -> int:
    if os.environ.get("MERGE_SKILLS", "on").lower() == "off":
        print("# /merge-skills disabled (MERGE_SKILLS=off)")
        return 0

    if len(sys.argv) < 3:
        print("# usage: merge-skills.py <pathA> <pathB>", file=sys.stderr)
        return 2

    path_a, path_b = Path(sys.argv[1]), Path(sys.argv[2])
    for p, label in ((path_a, "Skill A"), (path_b, "Skill B")):
        if not p.is_file():
            print(f"# error: {label} path not a file: {p}", file=sys.stderr)
            return 2

    content_a = read_skill(path_a)[:MERGE_BODY_TRUNC]
    content_b = read_skill(path_b)[:MERGE_BODY_TRUNC]
    name_a, name_b = path_a.parent.name, path_b.parent.name

    prompt = _build_synthesis_prompt(name_a, content_a, name_b, content_b)
    synthesized, err = invoke_synthesizer(prompt)
    if err:
        print(f"# synthesis failed: {err}", file=sys.stderr)
        return 1
    if not synthesized.strip():
        print("# synthesis returned empty output", file=sys.stderr)
        return 1

    proposed = _parse_proposed_name(synthesized)
    name = _sanitize_name(proposed, name_a, name_b)

    try:
        draft_path = write_draft(synthesized, name)
    except FileExistsError as e:
        print(f"# error: {e}", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"# write failed: {e}", file=sys.stderr)
        return 1

    print(f"# draft written to: {draft_path}")
    print_diffs(path_a, path_b, draft_path)
    print(f"\nReview the draft at {draft_path}.")
    print("To accept:")
    print(f"  mv {draft_path.parent} {skills_root()}/{name}")
    print(f"  rm -rf {path_a.parent} {path_b.parent}")
    print("To reject:")
    print(f"  rm -rf {draft_path.parent}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
