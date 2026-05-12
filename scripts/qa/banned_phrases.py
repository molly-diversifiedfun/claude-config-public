#!/usr/bin/env python3
"""
banned_phrases.py — grep content files for banned phrases / AI tells / PM jargon.

Used by @content-qa in checklist mode. Reads patterns from learned/banned-phrases.md.
Outputs JSON: { "violations": [{"line": N, "phrase": "...", "category": "..."}] }

Usage:
  python3 scripts/qa/banned_phrases.py <file>
  python3 scripts/qa/banned_phrases.py --diff <file>   # only newly-added lines
"""

import json
import re
import sys
from pathlib import Path

LEARNED_DIR = Path.home() / ".claude" / "skills" / "learned"

# Hardcoded fallbacks if learned/banned-phrases.md doesn't exist yet.
DEFAULT_BANNED = {
    "ai_tell": [
        r"\bdelve\b", r"\btapestry\b", r"\bnavigate the landscape\b",
        r"it's not just \w+, it's", r"let's dive in", r"in today's fast-paced",
        r"\bleverage\b", r"\bsynergy\b", r"best-in-class", r"\bunlock\b",
        r"\bempower\b", r"revolutionize", r"it's worth noting",
        r"\bessentially\b", r"\bfundamentally\b", r"at the end of the day",
    ],
    "pm_jargon": [
        r"\bscope\b", r"\bsprint\b", r"\bstandup\b", r"\bdecompose\b",
        r"\bbacklog\b", r"\broadmap\b",
    ],
    "wrong_handle": [r"@mollywood", r"@molly_shelestak"],
    "banned_number": [r"\b47\b"],
}


def load_patterns():
    src = LEARNED_DIR / "banned-phrases.md"
    if not src.exists():
        return DEFAULT_BANNED
    # Future: parse markdown sections for live updates
    return DEFAULT_BANNED


def scan(path: Path, diff_mode: bool = False) -> list[dict]:
    patterns = load_patterns()
    violations = []
    lines = path.read_text().splitlines()
    for i, line in enumerate(lines, start=1):
        for category, pats in patterns.items():
            for p in pats:
                if re.search(p, line, flags=re.IGNORECASE):
                    violations.append({
                        "line": i,
                        "phrase": p,
                        "category": category,
                        "context": line.strip()[:120],
                    })
    return violations


def main():
    args = sys.argv[1:]
    diff_mode = "--diff" in args
    files = [a for a in args if not a.startswith("--")]
    if not files:
        print("usage: banned_phrases.py [--diff] <file>", file=sys.stderr)
        sys.exit(1)
    out = {"violations": []}
    for f in files:
        out["violations"].extend(scan(Path(f), diff_mode))
    print(json.dumps(out, indent=2))
    sys.exit(1 if out["violations"] else 0)


if __name__ == "__main__":
    main()
