---
name: video-script
description: Generate batch talking-head video scripts (60-90 seconds) for Instagram Reels and short-form video. Optimized for solo creator filming sessions — outputs 3-5 scripts per batch with filming notes, energy cues, and look-at-camera moments. Voice-matched via Voice DNA profiles. NOT for YouTube long-form — use youtube-scriptwriting for that.
triggers:
  - video script
  - reel script
  - filming scripts
  - batch scripts
  - talking head script
  - write reel
  - batch filming
  - filming session
allowed-tools: Read Write Edit Grep Glob
---

<!-- Auto-inject brand config if available -->
Brand config: !`cat unstuck/brand-config.json 2>/dev/null || echo "No brand config found — using defaults"`

# Video Script — Batch Talking-Head Script Generator

Generate 3-5 voice-matched scripts per filming session for Instagram Reels and short-form video.

## Before Writing

**Step 1: Load brand context.**

1. **Voice DNA**: `content-system/{brand}/{brand}-voice-dna.md`
2. **Brand rules**: `.claude/rules/brands/{brand}.md`
3. **Content calendar** (if exists): `content-system/{brand}/calendars/YYYY-MM.md`

**Step 2: Understand the format.**

These are NOT YouTube videos. They are:
- 60-90 seconds (hard limit — Instagram Reels sweet spot)
- Talking head — one person speaking directly to camera
- Filmed in batches of 3-5 (same session, same setup)
- Designed for mobile-first viewing (vertical 9:16)
- The viewer decides in 3 seconds whether to keep watching

## Script Structure

Every script follows this pattern:

```
HOOK (0-3 seconds)
├── What stops the scroll
├── Must work with sound OFF (text overlay)
└── Must work with sound ON (spoken word)

PROBLEM (3-15 seconds)
├── Name the specific situation
├── Make the viewer feel seen
└── Use "you" language

INSIGHT (15-50 seconds)
├── The reframe, teaching, or story
├── ONE idea only — not a listicle
├── This is where the value lives
└── Use the brand's signature rhetorical moves

CTA (50-60/90 seconds)
├── Specific next step
├── NOT "follow for more" or "like and share"
└── Map to: Calendly, quiz, email list, website, DM
```

## Batch Filming Format

When generating a batch (3-5 scripts), include:

### Batch Filming Guide

```markdown
## Filming Session: [Date/Theme]
**Scripts:** [N]
**Total filming time:** ~[N] minutes (with setup/resets)
**Recommended order:** [order that minimizes outfit/energy changes]

### Setup Notes
- **Location:** [consistent backdrop recommendation]
- **Outfit:** [consistency notes — same outfit for series, different for standalone]
- **Lighting:** [natural/ring light/window]
- **Energy arc:** Start with [highest energy script], end with [most conversational]
```

## Script Format

```markdown
### Script [N]: [Working Title]
**Duration:** ~[N] seconds
**Pillar:** [content pillar]
**Hook type:** [contrarian/problem-first/surprising-fact/story-open/unpopular-opinion]
**Energy:** [calm/medium/high]
**Tone:** [conversational/authoritative/vulnerable/playful]

---

**HOOK (0-3 sec)** 🎬
> [Exact words. This is what they hear/read first.]

*[Camera note: look directly at lens, slight lean in]*

**PROBLEM (3-15 sec)**
> [Set up the pain. Be specific. Use "you."]
> [Second beat — make it visceral.]

*[Camera note: natural gestures, slight head shake on the pain point]*

**INSIGHT (15-50 sec)**
> [The reframe. The teaching. The story.]
> [Build the argument in spoken rhythm.]
> [Use short sentences. Pause for emphasis.]
> [Land the key line — this is the quotable moment.]

*[Camera note: energy shift here — lean forward for emphasis on key line]*
*[Camera note: look away briefly before key line, then back to lens for delivery]*

**CTA (50-60 sec)** 📌
> [Specific ask. Direct. One action.]

*[Camera note: warm but direct energy, slight smile]*

---

**Text overlay suggestions:**
- Hook text: [what to display in first 3 sec]
- Key line: [the quotable moment to highlight]
- CTA text: [what to display at end]

**Caption (for posting):**
[Short caption that reinforces the Reel's message. Under 2200 chars.]

**Hashtags:** [15-20]
```

## Quality Rules

Every script MUST pass:

- [ ] **60-90 seconds when read at speaking pace** (~150 words/minute)
- [ ] **ONE clear idea** — not a compressed listicle
- [ ] **Hook works with sound OFF** — text overlay must carry the hook alone
- [ ] **Speakable** — no written-word phrasing, no tongue-twisters
- [ ] **Uses contractions** — "you're" not "you are," "don't" not "do not"
- [ ] **Voice DNA compliance** — banned words absent, brand rhetorical moves present
- [ ] **No AI tells** — no "In today's world," no "Let me share," no "Here's the deal"
- [ ] **CTA maps to real conversion** — Calendly, quiz, email list. Not "follow for more."
- [ ] **Camera notes are actionable** — specific moments, not vague "be energetic"
- [ ] **Each script in the batch uses a DIFFERENT hook type**

## Word Count Guide

| Duration | Word Count | Sections |
|----------|-----------|----------|
| 60 sec | 140-160 words | Hook (15) + Problem (30) + Insight (80) + CTA (20) |
| 75 sec | 170-190 words | Hook (15) + Problem (40) + Insight (110) + CTA (20) |
| 90 sec | 200-225 words | Hook (15) + Problem (45) + Insight (140) + CTA (25) |

## Post-Production AI-Tell Sweep (MANDATORY)

Before delivering any batch, run this sweep on ALL scripts:

1. **Number check:** Search for 47 (AI's favorite). Replace. Ensure no number repeats across scripts in the batch.
2. **Tool/reference diversity:** Don't reference the same app/tool in every script. Rotate: Figma, Vercel, Stripe, VS Code, Notion, Linear, etc.
3. **Parallel structure:** If 3+ sentences in a row have the same structure, break the pattern.
4. **Handle check:** Use the correct Instagram handle from brand rules (e.g., @your-handle).

## Input

1. **Topics** — from `/content-matrix`, `/repurpose`, or user-provided
2. **Brand** — which brand (default: unstuck)
3. **Batch size** — 3-5 scripts (default: 5)
4. **Duration target** — 60, 75, or 90 seconds (default: 60-75)

## Output Location

Save to: `content-system/{brand}/content/YYYY-MM/video-batch-[date].md`

Include all scripts + the batch filming guide in one file.

## Integration

- **Upstream:** Topics from `/content-matrix` or insights from `/repurpose`
- **Downstream:** The user films from these scripts. Reel covers generated by nano-banana.
- **Chains with:** `hooks` (hook generation), Voice DNA (voice enforcement)
- **References:** `youtube-scriptwriting` for longer-form video (5+ minutes, different structure)

## What This Skill Does NOT Do

- Write YouTube long-form scripts (use `youtube-scriptwriting`)
- Edit or produce video (provides scripts only)
- Schedule or post videos (that's the distribution layer)
- Generate B-roll footage (provides B-roll suggestions only)
