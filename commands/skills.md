---
description: Find the best skill for what you want to do. Semantic search over ~600 installed skills.
---

# /skills — semantic skill catalog

Query: $ARGUMENTS

You are helping the user find the best skill for a specific need.

If `$ARGUMENTS` is empty or whitespace-only, respond ONLY with the following two lines and stop:
> Usage: /skills 'what you want to do'
> Example: /skills 'audit hook safety'

Otherwise, the deterministic prefilter has produced these candidates:

!`bash ~/.claude/scripts/skills-prefilter.sh "$ARGUMENTS"`

Read the candidate list above. Each line is `<name>|<archetypes>|<description-excerpt>|<untried-flag>`. The fourth column is the literal string `untried` (skill has <3 bake-off appearances) or empty.

Rank the top 5 candidates against the query. When column 4 == `untried`, prefix the skill name in your rendered list with `✨ ` (sparkle + space) to signal "no /bake-off data yet — worth a spin." Output as a numbered markdown list:

  1. **<skill-name>** — <one-line rationale: why this fits, concrete, no fluff>
  2. ...

Each rationale should reference a concrete piece of the query (don't restate the skill description).

If the prefilter emitted `# No matches found` or fewer than 3 reasonable candidates, say so explicitly and suggest 2-3 ways to rephrase the query. Do NOT fabricate skills that aren't in the candidate list.
