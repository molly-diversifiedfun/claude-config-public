#!/usr/bin/env bash
# sanitize-for-public.sh — produce a public-facing snapshot of claude-config.
#
# Strips brand names, project names, contact info, and session-specific files
# while keeping author attribution intact. Output is a parallel directory you
# can review, then push to its own GitHub repo.
#
# Usage:   ./bin/sanitize-for-public.sh [target-dir]
# Default: ../claude-config-public/

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-${REPO_DIR}/../claude-config-public}"

if [ -e "$TARGET" ]; then
  echo "Error: $TARGET already exists. Remove or pick a different target." >&2
  exit 1
fi

echo "→ snapshotting $REPO_DIR → $TARGET (excluding personal/session files)"
rsync -a \
  --exclude='.git' \
  --exclude='.DS_Store' \
  --exclude='HANDOFF.md' \
  --exclude='.ship/' \
  --exclude='skills/brand-voice-router/' \
  --exclude='skills/learned/qa-rules.md' \
  --exclude='skills/learned/research-budgets.md' \
  --exclude='docs/specs/' \
  --exclude='docs/plans/' \
  --exclude='settings.local.json' \
  "$REPO_DIR/" "$TARGET/"

cd "$TARGET"

echo "→ stripping email addresses, handles, brand names"
# Run sed on all text files. macOS sed needs -i ''.
SED_INPLACE=(sed -i '')
[ "$(uname)" = "Linux" ] && SED_INPLACE=(sed -i)

# Use find + xargs to apply across all .md, .sh, .json files (no binaries)
find . -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' -o -name '*.html' \) \
  -not -path './.git/*' \
  -print0 \
| while IFS= read -r -d '' f; do
  # Personal handles + emails
  "${SED_INPLACE[@]}" -e 's/molly\.shelestak@gmail\.com/your-email@example.com/g' "$f"
  "${SED_INPLACE[@]}" -e 's/@your-handle/@your-handle/g' "$f"
  "${SED_INPLACE[@]}" -e 's/@your-handle/@your-handle/g' "$f"
  "${SED_INPLACE[@]}" -e 's/<your-github-username>/<your-github-username>/g' "$f"
  # Brand names
  "${SED_INPLACE[@]}" -e 's/<your brand>/<your brand>/g' "$f"
  "${SED_INPLACE[@]}" -e 's/<your second brand>/<your second brand>/g' "$f"
  "${SED_INPLACE[@]}" -e 's/Outli\.ne/<your third brand>/g' "$f"
  # Project names (case-sensitive — preserves "venue" as a common word)
  "${SED_INPLACE[@]}" -e 's/<your-project-1>/<your-project-1>/g' "$f"
  "${SED_INPLACE[@]}" -e 's/<your-project-1>/<your-project-1>/g' "$f"
  "${SED_INPLACE[@]}" -e 's/<your-project-2>/<your-project-2>/g' "$f"
  "${SED_INPLACE[@]}" -e 's/<your-project-2>/<your-project-2>/g' "$f"
done

echo "→ replacing brand-voice-router with a template"
mkdir -p skills/brand-voice-router
cat > skills/brand-voice-router/SKILL.md <<'TEMPLATE'
---
name: brand-voice-router
description: Template — replace with your own brand-voice routing. Auto-detect which of your brands a content request belongs to and apply the correct voice, tone, audience, and positioning. Use whenever you request content creation, copy, social posts, emails, marketing materials. Also use when you ask to write something and haven't specified which brand.
---

# Brand Voice Router (TEMPLATE)

This is a stub. The original was specific to your three brands and you Direct lane. Replace this file with your own brand routing logic.

## Pattern

The original skill detected which brand a request belonged to from context, then loaded the right voice profile, lexicon, and anti-patterns. Common detection signals:
- Explicit brand name in the prompt
- Project directory (cwd)
- Audience cues ("for LinkedIn" vs "for my newsletter")
- Content type fingerprints

## Recommended structure

```
skills/brand-voice-router/
  SKILL.md              # this file — describes routing logic + triggers
  brands/
    brand-1/voice.md    # one file per brand with voice profile
    brand-2/voice.md
    brand-3/voice.md
  references/
    detection-rules.md  # cwd → brand, keyword → brand maps
```

## Integration

Chain with:
- `humanize-ai-writing` — strip AI patterns after applying brand voice
- `content-platform-adapter` — adapt brand-voiced content for IG/LinkedIn/etc.
- CARL `WRITING` domain — always-on voice rules

Replace the template content with your actual brand profiles, then this skill becomes the gateway for all content work.
TEMPLATE

echo "→ writing HANDOFF.md placeholder"
cat > HANDOFF.md <<'HANDOFF'
# HANDOFF — Session Continuity Notes

This file is a session-handoff tracker. The public template intentionally ships empty so you can start your own.

## Purpose

After every significant session, log:
- What changed (with commit hashes)
- What decisions you made
- What's open for next session
- Any new state in `~/.claude/` worth knowing about

The Stop hook `session-retrospective.sh` checks that this file has been touched today as part of the Definition of Done.

## How to use

Replace this content with your own running notes. See `rules/common/definition-of-done.md` for the full DoD checklist.
HANDOFF

echo "→ writing CHECKLIST.md placeholder if missing"
# CHECKLIST.md likely already came over from the rsync — leave it
echo ""
echo "✓ sanitize complete."
echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Review the diff: 'diff -r $REPO_DIR . | head -50'"
echo "  3. Replace README.md with a public-facing version (see template above)"
echo "  4. git init && git add . && git commit -m 'initial public snapshot'"
echo "  5. Create new GitHub repo, push, set visibility to public"
