---
description: Merge two overlapping SKILL.md files into a draft via Sonnet synthesis. Read-only on originals; writes to ~/.claude/skills/_drafts/. Use after /consolidate-skills surfaces SEMANTIC tier candidates.
---

<!-- Kill switch + Python invocation -->
```bash
[ "$MERGE_SKILLS" = "off" ] && { echo "# /merge-skills disabled (MERGE_SKILLS=off)"; exit 0; }
```

Usage: /merge-skills <pathA> <pathB>

Where <pathA> and <pathB> are full paths to two SKILL.md files (typically surfaced as overlapping by /consolidate-skills SEMANTIC tier).

Invokes `python3 ~/.claude/scripts/merge-skills.py "$@"`.

The script:
- Reads both SKILL.md files
- Uses Sonnet 4.6 to synthesize a single merged SKILL.md (the model proposes a name in the draft frontmatter)
- Writes the draft to ~/.claude/skills/_drafts/<name>/SKILL.md
- Prints `diff -u` of draft vs both originals (stderr)
- Prints acceptance instructions (manual `mv` + `rm`)

NEVER modifies the original skill files. NEVER auto-deletes.

Kill switch: MERGE_SKILLS=off
