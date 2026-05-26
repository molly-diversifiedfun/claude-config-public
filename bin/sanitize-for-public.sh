#!/usr/bin/env bash
# sanitize-for-public.sh — produce a public-facing snapshot of claude-config.
#
# Strips brand names, project names, contact info, and session-specific files
# while keeping author attribution intact. Output is a parallel directory you
# review, then push to its own GitHub repo.
#
# Usage:   ./bin/sanitize-for-public.sh [target-dir]
# Default: ../claude-config-public/
#
# ⚠️  THIS SCRIPT GETS YOU ~85% OF THE WAY. A MANUAL CLEANUP PASS IS REQUIRED
#     after running it — see the "Manual pass needed" checklist printed at the
#     end. Semantic leakage (personal stories inside prose, grammar artifacts
#     from sed substitutions, doc count reconciliation) can't be automated.

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
  --exclude='TASKS.md' \
  --exclude='.ship/' \
  --exclude='skills/brand-voice-router/' \
  --exclude='skills/ai-build-partner/' \
  --exclude='skills/learned/qa-rules.md' \
  --exclude='skills/learned/research-budgets.md' \
  --exclude='skills/learned/competitive-history.md' \
  --exclude='skills/learned/hook-performance.md' \
  --exclude='docs/specs/' \
  --exclude='docs/plans/' \
  --exclude='docs/site/' \
  --exclude='commands/unstuck.md' \
  --exclude='commands/canva-carousel.md' \
  --exclude='commands/sync-notion.md' \
  --exclude='rules/content-system/' \
  --exclude='settings.local.json' \
  --exclude='carl/content-rules' \
  --exclude='carl/writing' \
  --exclude='carl/n8n' \
  --exclude='carl/manifest' \
  "$REPO_DIR/" "$TARGET/"

cd "$TARGET"

echo "→ sed-substituting personal references"
# macOS sed needs `-i ''`; Linux sed needs `-i`.
SED_INPLACE=(sed -i '')
[ "$(uname)" = "Linux" ] && SED_INPLACE=(sed -i)

find . -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.json' -o -name '*.html' \) \
  -not -path './.git/*' \
  -print0 \
| while IFS= read -r -d '' f; do
  # --- Emails + handles + GitHub user ---
  "${SED_INPLACE[@]}" \
    -e 's/molly\.shelestak@gmail\.com/your-email@example.com/g' \
    -e 's/@your-handle/@your-handle/g' \
    -e 's/@your-handle/@your-handle/g' \
    -e 's/@your-wrong-handle/@your-wrong-handle/g' \
    -e 's/@your-wrong-handle-3/@your-wrong-handle-3/g' \
    -e 's|@welcome\\.to\\.mollywood|@your-wrong-handle-2|g' \
    -e 's/<your-github-username>/<your-github-username>/g' \
    "$f"

  # --- Brand names ---
  "${SED_INPLACE[@]}" \
    -e 's/<your brand>/<your brand>/g' \
    -e 's/<your second brand>/<your second brand>/g' \
    -e 's/Outli\.ne/<your third brand>/g' \
    -e 's|<your-direct-lane>|<your-direct-lane>|g' \
    "$f"

  # --- Project names (case variants) ---
  "${SED_INPLACE[@]}" \
    -e 's/<your-project-1>/<your-project-1>/g' \
    -e 's/<your-project-1>/<your-project-1>/g' \
    -e 's/<your-project-2>/<your-project-2>/g' \
    -e 's/<your-project-2>/<your-project-2>/g' \
    -e 's/<your nonfiction project>/<your nonfiction project>/g' \
    -e 's/<your-agent-project>/<your-agent-project>/g' \
    -e 's/<your-agent-project>/<your-agent-project>/g' \
    -e 's/<your-personal-ai-project>/<your-personal-ai-project>/g' \
    -e 's/\bnancy\b/<your-personal-ai-project>/g' \
    -e 's/\bunstuck\b/<your-content-brand>/g' \
    -e 's/\bUnstuck\b/<your-content-brand>/g' \
    "$f"

  # --- Personal stories the LLM-as-content-writer must not see ---
  "${SED_INPLACE[@]}" \
    -e 's/<your signature project>/<your signature project>/g' \
    -e 's/<your signature project>/<your signature project>/g' \
    -e 's/<your unlaunched-thing example>/<your unlaunched-thing example>/g' \
    -e 's/<your unlaunched-thing example>/<your unlaunched-thing example>/g' \
    -e 's/<your never-shipped-thing example>/<your never-shipped-thing example>/g' \
    -e 's/<your never-shipped-thing example>/<your never-shipped-thing example>/g' \
    -e 's/\<your big-success example>/<your big-success example>/g' \
    -e 's/\<your big-success example>/<your big-success example>/g' \
    -e 's/<your specific public stories>/<your specific public stories>/g' \
    "$f"

  # --- Operator-of-system references ("Molly does X" → "you do X") ---
  "${SED_INPLACE[@]}" \
    -e 's/with the user\./with the user./g' \
    -e 's/with the user,/with the user,/g' \
    -e 's/with the user/with the user/g' \
    -e 's/asking the user/asking the user/g' \
    -e 's/Asks the user/Asks the user/g' \
    -e 's/Ask the user:/Ask the user:/g' \
    -e 's/ask the user/ask the user/g' \
    -e 's/the user says/the user says/g' \
    -e 's/the user sends/the user sends/g' \
    -e 's/the user approves/the user approves/g' \
    -e 's/the user handles/the user handles/g' \
    -e 's/corrected by the user/corrected by the user/g' \
    -e 's/Confirmed by the user/Confirmed by the user/g' \
    -e "s/your/your/g" \
    -e 's/from the user/from the user/g' \
    -e 's/to the user/to the user/g' \
    -e 's/^Molly /You /g' \
    -e 's/ you / you /g' \
    -e 's/ Molly\./ the user./g' \
    -e 's/ the user,/ the user,/g' \
    "$f"

  # --- Hard-coded paths ---
  "${SED_INPLACE[@]}" \
    -e 's|/Users/molly\.shelestak|$HOME|g' \
    -e 's|<your-content-workspace>|<your-content-workspace>|g' \
    -e 's|<your-content-workspace-2>|<your-content-workspace-2>|g' \
    -e 's|<your-product-workspace>|<your-product-workspace>|g' \
    -e 's|<your-side-project>|<your-side-project>|g' \
    -e 's|<your-saas-project>|<your-saas-project>|g' \
    -e 's|<your-workspace>|<your-workspace>|g' \
    "$f"

  # --- Banned-phrase regex literals in QA scripts ---
  "${SED_INPLACE[@]}" \
    -e 's/r"@your-wrong-handle"/r"@your-wrong-handle"/g' \
    "$f"

  # --- CHECKLIST narrative ("your primary machine → new machine") ---
  "${SED_INPLACE[@]}" \
    -e 's/your primary machine/your primary machine/g' \
    -e 's/your primary machine/your primary machine/g' \
    "$f"
done

echo "→ replacing brand-voice-router/ with a template stub"
mkdir -p skills/brand-voice-router
cat > skills/brand-voice-router/SKILL.md <<'TEMPLATE'
---
name: brand-voice-router
description: Template — replace with your own brand-voice routing. Auto-detect which of your brands a content request belongs to and apply the correct voice, tone, audience, and positioning. Use whenever you request content creation, copy, social posts, emails, marketing materials. Also use when you ask to write something and haven't specified which brand.
---

# Brand Voice Router (TEMPLATE)

This is a stub. The original was specific to the author's three brands and direct-author lane. Replace this file with your own brand routing logic.

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

echo "→ writing HANDOFF.md template (private one was excluded)"
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

echo ""
echo "✓ automated sanitize complete."
echo ""
echo "═════════════════════════════════════════════════════════════════════"
echo "  MANUAL PASS NEEDED — these can't be automated:"
echo "═════════════════════════════════════════════════════════════════════"
cat <<'MANUAL'

1. Rewrite README.md for the public audience.
   - Strip "your your primary machine → new Mac mini" framing
   - Add destructive-install warning above Quick Start
   - Disambiguate install.sh (sync) vs bootstrap.sh (fresh-Mac one-shot)
   - Add cherry-pick path for power users with existing setup
   - Point to companion repos (claude-skills)

2. Update install.sh safety:
   - Add destructive warning in header
   - Detect existing ~/.claude content + prompt before rsync --delete
   - Add --yes flag for scripted use
   - Make settings.local.json copy conditional on file existing

3. Reframe CHECKLIST.md from "primary machine sync" to "post-install":
   - Soften MCP list ("the original used these — pick what you need")
   - Replace external-repo placeholders with explanation
   - Drop machine-to-machine migration framing

4. Reconcile doc counts after exclusions:
   - docs/architecture.md (commands 20→18, rules 13→11 in 4→3 domains)
   - docs/commands.md (20→18)
   - docs/hooks.md (22→21)
   - docs/rules.md (remove content-system section, add note)
   - README.md table

5. Update files that reference excluded content:
   - docs/ship-pipeline-v2.md (dead spec/plan paths)
   - skills/learned/SKILL.md (remove CONTENT-RULES enforcement column)
   - CLAUDE.md (remove CONTENT-RULES from CARL domain list)

6. Heavy-rewrite skills/learned/never-fabricate.md:
   - The file's example IS the author's career; sed can't gracefully replace
   - Rewrite to keep the lesson + template placeholders

7. Grammar artifact sweep — sed leaves debris like "you has made":
   grep -rE "\byou has\b|\byou was\b" --include='*.md' .

8. Add LICENSE if missing.

9. Smoke-test the install: HOME=/tmp/test bash bin/install.sh

10. Author attribution stays in README, LICENSE, and this script — intentional.

═════════════════════════════════════════════════════════════════════
MANUAL

echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Walk the manual checklist above"
echo "  3. Verify: grep -rln 'Molly\\|molly' --include='*.md' . | grep -v README"
echo "  4. git init && git add . && git commit -m 'initial public snapshot'"
echo "  5. gh repo create <name> --public --source=. --remote=origin --push"
