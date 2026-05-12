---
name: hooks
description: Generate 5 brand-voice-matched hook variants per topic using proven psychological frameworks. Use when writing Instagram captions, carousel openers, Reel hooks, email subject lines, or any content that needs a scroll-stopping opening. Chains with Voice DNA profiles and humanize-ai-writing for brand compliance.
triggers:
  - write hooks
  - hook variants
  - generate hooks
  - scroll-stopping hooks
  - instagram hooks
  - content hooks
  - hook me
allowed-tools: Read Write Edit Grep Glob
---

<!-- Auto-inject brand config if available -->
Brand config: !`cat unstuck/brand-config.json 2>/dev/null || echo "No brand config found — using defaults"`

# Hooks — Brand Voice Hook Generator

Generate 5 structurally distinct hook variants per topic, enforced against a brand's Voice DNA profile.

## Before Writing Any Hook

**Step 1: Load brand context.** Read these files in order:

1. **Voice DNA**: `content-system/{brand}/{brand}-voice-dna.md` — the operational voice profile
2. **Brand rules**: `.claude/rules/brands/{brand}.md` — vocabulary and positioning rules
3. **Content strategy** (if exists): `content-system/{brand}/strategy.md` — pillars and audience

If no brand is specified, ask. If Voice DNA doesn't exist, stop and tell the user to run `voice-extractor` first.

**Step 2: Extract hook constraints from Voice DNA:**
- Banned vocabulary (never use these words in hooks)
- Required vocabulary (prefer these terms)
- Tone dimensions (directness level, warmth level, authority level)
- Opening patterns (what the brand's openings sound like)
- Anti-patterns (what this voice never does)

## The 5 Hook Frameworks

For every topic, generate exactly 5 hooks — one per framework. Each must be structurally different from the others.

### 1. Contrarian
Challenge conventional wisdom. Take a position most people disagree with.
- Pattern: "[Common belief] is wrong. Here's why."
- Pattern: "Stop [common advice]. It's making things worse."
- Pattern: "Everyone says [X]. Nobody mentions [Y]."

### 2. Problem-First
Name the pain before anything else. Make the reader feel seen.
- Pattern: "You [specific frustrating situation]."
- Pattern: "[Vivid description of the stuck moment]."
- Pattern: "That feeling when [specific relatable frustration]."

### 3. Surprising Fact
Lead with unexpected data or a counterintuitive truth.
- Pattern: "[Specific number]% of [group] [surprising behavior]."
- Pattern: "The average [person] spends [surprising amount] on [thing]."
- Pattern: "[Authority] found that [counterintuitive result]."

### 4. Story-Open
Start mid-narrative. Drop the reader into a scene.
- Pattern: "It was [specific moment] when [realization]."
- Pattern: "[Specific day/time]. [Vivid scene]. [Twist]."
- Pattern: "I [embarrassing/vulnerable specific action]. Here's what happened."

### 5. Unpopular Opinion
Stake a clear position. Not controversy for its own sake — a genuine belief backed by experience.
- Pattern: "[Strong declarative statement about the topic]."
- Pattern: "I don't care what [authority/consensus] says. [Position]."
- Pattern: "[Thing everyone loves] is overrated. [Better alternative]."

## Hook Scoring (MANDATORY)

After generating all 5 hooks, score each on three dimensions (1-10):

| Dimension | What It Measures | Threshold |
|---|---|---|
| **Specificity** | Does this hook contain a detail only this brand could say? A named tool, a specific number, a real scenario? Or is it generic enough to appear on any business account? | ≥7 |
| **Scroll-stop** | Would someone moving at thumb-speed pause on this? Does it create a micro-moment of recognition ("wait, that's me") or tension ("wait, is that true?")? | ≥7 |
| **Brand fit** | Does this sound like the brand — PM vocabulary, anti-hustle, infrastructure framing? Or could a life coach, productivity guru, or hustle-culture influencer have written it? | ≥7 |

**Any hook scoring below 7 on ANY dimension gets an automatic rewrite.** Do not deliver sub-7 hooks.

**The brand-distinctiveness test:** If you covered the @handle, could this hook come from ANY business account? If yes, it fails Brand fit regardless of the number score.

**The audience proxy test (Unstuck):** Would a Staff Engineer at Stripe, mid-scroll at 11pm, stop and read this? If no, it fails Scroll-stop.

## Hook Quality Rules

Every hook MUST pass these checks:

- [ ] **Under 125 characters** for Instagram preview (the fold)
- [ ] **No banned vocabulary** from brand rules
- [ ] **Uses brand-preferred vocabulary** where natural (don't force it)
- [ ] **Matches brand tone dimensions** (e.g., if brand is 8/10 direct, hooks should be direct)
- [ ] **Structurally distinct** — no two hooks use the same opening pattern
- [ ] **Standalone** — each hook makes sense without the rest of the content
- [ ] **No AI tells** — no "In today's world," "Let's dive in," "Here's the thing about," "Have you ever wondered"
- [ ] **Active voice** — no passive constructions
- [ ] **Specific over vague** — use numbers, names, concrete details

## Voice Pipeline

After generating all 5 hooks:

1. **Self-audit against Voice DNA** — re-read each hook and check every Critical Rule from the Voice DNA
2. **Kill AI patterns** — apply humanize-ai-writing principles: remove filler, hedging, corporate speak
3. **Read aloud test** — each hook should sound natural spoken aloud, not written

## Post-Production AI-Tell Sweep (MANDATORY)

Before delivering hooks, check:
1. **No "47"** or other AI-favorite numbers. Use varied, specific numbers.
2. **Tool diversity** — don't default to Notion for every reference.
3. **No parallel structure** across the 5 variants — each should feel structurally different, not just word-swapped.

## Input

Ask the user for:
1. **Topic** — what the content is about
2. **Brand** — which brand (default: unstuck)
3. **Platform** — Instagram caption, email subject, carousel slide 1, Reel opening (default: Instagram caption)
4. **Context** (optional) — what pillar this falls under, what the full piece is about

## Output Format

```markdown
# Hooks: [Topic]
**Brand:** [brand] | **Platform:** [platform] | **Pillar:** [pillar if known]

## 1. Contrarian
> [Hook text]

**Char count:** [N] | **Opening structure:** [what makes it contrarian]

## 2. Problem-First
> [Hook text]

**Char count:** [N] | **Opening structure:** [what pain it names]

## 3. Surprising Fact
> [Hook text]

**Char count:** [N] | **Opening structure:** [what makes the fact surprising]

## 4. Story-Open
> [Hook text]

**Char count:** [N] | **Opening structure:** [what scene it drops into]

## 5. Unpopular Opinion
> [Hook text]

**Char count:** [N] | **Opening structure:** [what position it stakes]

---

**Scores:**
| Hook | Specificity | Scroll-stop | Brand fit | Overall |
|------|------------|-------------|-----------|---------|
| 1. Contrarian | X/10 | X/10 | X/10 | X/10 |
| 2. Problem-First | X/10 | X/10 | X/10 | X/10 |
| 3. Surprising Fact | X/10 | X/10 | X/10 | X/10 |
| 4. Story-Open | X/10 | X/10 | X/10 | X/10 |
| 5. Unpopular Opinion | X/10 | X/10 | X/10 | X/10 |

**Voice compliance:** [✅ Passed / ⚠️ Notes]
**Recommended for this topic:** [which 1-2 hooks are strongest and why, with score rationale]
```

## Integration

- **Upstream:** Called by `/repurpose`, `/carousel-writer`, `/content-matrix` when generating content
- **Downstream:** Hook text feeds into carousel Slide 1, Reel first 3 seconds, Instagram caption opening
- **Voice enforcement:** Always reads Voice DNA before generating. Never generates hooks without brand context.

## What This Skill Does NOT Do

- Write full content pieces (use `/repurpose` or `content-atomizer`)
- Generate landing page copy (use `copywriting` or `direct-response-copy`)
- Create visual hooks (use nano-banana or Canva MCP)
- Write email sequences (use `email-sequence`)
