#!/usr/bin/env python3
"""
pillar_cta_check.py — verify caption file's CTA matches its declared pillar.

Mirror → share trigger ("send this to", "tag someone")
Machine → save trigger ("save this for") OR DM keyword
Proof   → DM keyword

Hard-fail rule (qa-rules item 13): pillar/CTA cross-violation fails the file.

Usage: python3 scripts/qa/pillar_cta_check.py <caption_file>
"""

import json
import re
import sys
from pathlib import Path

CTA_PATTERNS = {
    "mirror": [r"send this to", r"tag (someone|the friend|a friend)"],
    "machine": [r"save this for", r"DM me \w+", r"comment \w+ for"],
    "proof": [r"DM me \w+", r"book a call", r"work with me"],
}

FORBIDDEN_IN_MIRROR = [
    r"here's how", r"the fix is", r"step 1", r"step one",
    r"the framework", r"the system", r"the process is",
]


def parse_frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    end = text.find("---", 3)
    if end == -1:
        return {}
    fm = {}
    for line in text[3:end].strip().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
    return fm


def check(path: Path) -> dict:
    text = path.read_text()
    fm = parse_frontmatter(text)
    pillar = fm.get("pillar", "").lower()
    body = text.split("---", 2)[-1] if text.startswith("---") else text
    body_lower = body.lower()

    violations = []

    if pillar not in CTA_PATTERNS:
        violations.append({
            "rule": 11,
            "issue": f"Pillar declared as '{pillar}' — must be mirror|machine|proof",
        })
        return {"file": str(path), "violations": violations, "hard_fail": True}

    # Rule 13: CTA matches pillar
    has_valid_cta = any(
        re.search(p, body_lower) for p in CTA_PATTERNS[pillar]
    )
    if not has_valid_cta:
        violations.append({
            "rule": 13,
            "issue": f"No CTA matching pillar '{pillar}'",
            "expected": CTA_PATTERNS[pillar],
            "hard_fail": True,
        })

    # Rule 14: Mirror stops at agitate
    if pillar == "mirror":
        for pat in FORBIDDEN_IN_MIRROR:
            if re.search(pat, body_lower):
                violations.append({
                    "rule": 14,
                    "issue": f"Mirror pillar contains solution language: '{pat}'",
                    "hard_fail": True,
                })

    return {
        "file": str(path),
        "pillar": pillar,
        "violations": violations,
        "hard_fail": any(v.get("hard_fail") for v in violations),
    }


def main():
    if len(sys.argv) < 2:
        print("usage: pillar_cta_check.py <file>", file=sys.stderr)
        sys.exit(1)
    result = check(Path(sys.argv[1]))
    print(json.dumps(result, indent=2))
    sys.exit(1 if result["violations"] else 0)


if __name__ == "__main__":
    main()
