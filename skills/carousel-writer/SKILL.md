---
name: carousel-writer
description: Generate structured JSON carousel content ready for Canva MCP template injection. Outputs 7-10 slide content with headlines, body text, and CTAs that fit exact character constraints. Use when producing Instagram carousels from topics, outlines, or repurposed content.
triggers:
  - write carousel
  - carousel content
  - carousel slides
  - canva carousel
  - instagram carousel
  - slide content
  - carousel json
allowed-tools: Read Write Edit Grep Glob
---

<!-- Auto-inject brand config if available -->
Brand config: !`cat unstuck/brand-config.json 2>/dev/null || echo "No brand config found — using defaults"`

# Carousel Writer — Structured Content for Canva MCP

Generate 7-10 slide carousel content as structured JSON, ready for Canva template injection via MCP.

## Before Writing

**Step 1: Load brand context.**

1. **Voice DNA**: `content-system/{brand}/{brand}-voice-dna.md`
2. **Brand rules**: `.claude/rules/brands/{brand}.md`
3. **Canva template spec** (from implementation spec):
   - Slide 1 (Hook): Large headline, brand accent, cream background
   - Slides 2-9 (Content): Headline + body text, consistent layout
   - Slide 10 (CTA): Action headline + specific CTA

**Step 2: Get the content source.** Either:
- A carousel outline from `/repurpose` (preferred — already structured)
- A topic + pillar from `/content-matrix`
- A raw topic from the user

## Slide Constraints

These are hard constraints based on the Canva template text zones:

| Field | Max | Rationale |
|-------|-----|-----------|
| Slide headline | 8 words | Must be readable at Instagram thumbnail size |
| Slide body | 25 words | Text zone fits ~25 words at 18pt Outfit |
| CTA headline | 6 words | Bold, scannable |
| CTA body | 15 words | URL + brief instruction |
| Caption | 2200 chars | Instagram hard limit |
| Hashtags | 5 | 3-5 in caption after CTA (2026 algo change — NOT first comment) |

## Step 0: Select Framework by Pillar (MANDATORY)

Before writing ANY slides, determine the pillar and select the matching framework:

**MIRROR posts (50%) → PAS — stop at Agitate**
- Problem: name the specific pain with enough detail only someone who's lived it would know
- Agitate: twist the knife with a second, more specific detail
- STOP. Do NOT solve. The audience IS the validation. The "I feel attacked" reaction drives shares.
- Slide arc: Hook (problem) → Context (agitate) → Build (more specific examples) → Payoff (the gut punch) → CTA (share)
- CTA: "Send this to the friend who ___" (drives DM sends — #1 algorithm signal)
- Best hook types: problem-callout, contrarian, confession

**MACHINE posts (30%) → AIDA mapped to slides**
- Attention (Slide 1): contrarian or problem-callout hook, max 10 words
- Interest (Slides 2-3): why the conventional approach fails, specific examples
- Desire (Slides 4-6): the framework/steps, one numbered idea per slide
- Action (Slide 7+): save CTA + micro-commitment ("Screenshot slide 4 and do it today")
- CTA: "Save this for the next time you ___" (drives saves — #2 algorithm signal)
- Best hook types: contrarian, question, surprising-stat

**PROOF posts (20%) → BAB (Before-After-Bridge)**
- Before: the specific, messy starting point with real numbers and timeline
- After: the concrete result — numbers, timeline, real person from story banks
- Bridge: what changed (this is where the method lives, subtly)
- CTA: "Ready to ship? Link in bio." or "Drop a [emoji] if this is you"
- Best hook types: story-open, social-proof, surprising-stat

## Step 0.5: Select Visual Template (MANDATORY)

After selecting the framework, choose a visual template. Read `content-system/unstuck/visuals/templates/design-engine.md` for full design principles. Read `content-system/unstuck/visuals/templates/carousel-formats.md` for all 16 format specs.

**Template selection by content type:**

| Content Type | Best Template | Why |
|---|---|---|
| Deep reflection, polarizing take, essay | **10 — Essay Carousel** | Cream paper + serif = editorial authority |
| Habit change, identity shift, stop/start | **11 — Stop X / Start Y** | Clear visual contrast, pink/green indicators |
| Morning routine, "what I discovered", ritual reveal | **12 — Personal Discovery** | Lifestyle photo + white card = intimate feel |
| Belief scripts, prompts, insider knowledge | **13 — Secret Codes** | Warm gradient + white card = 103K-like viral format |
| Before/after transformation, mindset shift | **14 — Before/After** | Color-coded panels make the shift visible |
| Teaching a framework, mental model, hierarchy | **15 — Framework Diagram** | Color blocks on light bg = scannable and clear |
| Numbered skills, tools, step systems | **16 — Dark Card System** | Dark bg + pink accent = high perceived value |
| Self-assessment, diagnostic, "do you have these?" | **1 — Checklist** | Numbered items with alternating slides |
| Reframing bad advice, myth vs truth | **2 — Myth Buster** | Visual contrast between myth and truth |
| Personal story, client transformation | **3 — Story Arc** | Mixed media / collage, color progression |
| Step-by-step method, how-to process | **4 — Framework** | Clean, numbered steps with progress indicator |
| Unpopular opinion, contrarian position | **5 — Hot Take** | Dark bg, bold text, minimal design |
| X vs Y, before/after comparison | **6 — Comparison** | Split-screen layouts |

Add a `"visual_template"` field to the JSON output:
```json
"visual_template": "13-secret-codes"
```

Each template has HTML reference files in `unstuck/visuals/previews/{template}/` — use these as the visual style guide when producing slide HTML.

## Step 0.75: Target Archetype + Proof Source (MANDATORY)

**Identify the target archetype.** Every carousel must target ONE primary archetype:
- **Overtime Optimizer** — Sunday Notion ritual, no sprint plan
- **Perfectionist Creator** — redesigns but never launches
- **Golden Handcuffs Builder** — comp too good to leave, side project is "hobby"
- **Accidental Consultant** — freelance gigs, no pipeline or pricing

If the user doesn't specify, pick the best fit and state it. This affects word choice, pain points, and examples.

**Select proof for the Proof slide.** Use real client names and results:
- Eric Kanner, Aakash Niraula, Jai K., Tom D., Jeff Cotrupe, Calvin C., John Ruiz
- Or reference a signature story: <your signature project> (4 months), <your big-success example>, <your unlaunched-thing example>, <your never-shipped-thing example>

Never fabricate stories. Use "you" framing or real/famous examples only.

## Carousel Architecture

The narrative arc adapts based on framework selection above, but follows this general structure:

| Slide | Type | Purpose | Pattern |
|-------|------|---------|---------|
| 1 | Hook | Stop the scroll | Max 10 words. Must be readable at 161x200px thumbnail. Billboard, not paragraph. |
| 2 | Context + swipe cue | Set the stage | Name the problem or situation. Include swipe cue ("the last one changed everything"). |
| 3-4 | Build | Develop the argument | Evidence, examples, data. One idea per slide. |
| 5-7 | Teach/Payoff | Core value delivery | Steps, insights, frameworks, or story climax. |
| 7+ | CTA | Drive action | CTA matched to pillar (share/save/convert). @your-handle. |

**Slide count by format:**
- Checklist, Framework, Data Drop, Myth Buster: 8-12 slides
- Hot Take: 6-8 slides
- Story Arc, Quote Collection: 8-14 slides (longer when the story warrants it)
- Default: 7-10

**Mid-carousel soft CTA:** For 10+ slide carousels, add a soft CTA on slide 5-6: "Save this — we're not done."

**Rules:**
- Each slide advances ONE idea (no walls of text)
- Max 25 words per body slide. Max 8 words per headline.
- Progressive narrative — each slide builds on the last
- Slide 1 must work as a standalone image (it appears in the grid)
- Last slide CTA is specific and actionable — never "follow for more"
- Every slide should be independently "screenshot-able" — valuable on its own
- Dark background slides get shorter text (light text on dark = harder to read fast)
- End slides 1→2 and the midpoint with an incomplete thought that pulls forward

## Output Format

### Primary Output: JSON

```json
{
  "brand": "unstuck",
  "topic": "Your side project isn't stalled — it's under-built",
  "pillar": "mirror",
  "framework": "PAS",
  "format_subtype": "comparison",
  "visual_template": "06-comparison",
  "slide_count": 8,
  "hook": {
    "title": "Your side project isn't stalled",
    "subtitle": "the last slide hits different"
  },
  "slides": [
    {
      "number": 1,
      "type": "hook",
      "headline": "Your side project isn't stalled",
      "body": ""
    },
    {
      "number": 2,
      "type": "context",
      "headline": "You run standups at work",
      "body": "Your team ships because they have infrastructure. Your side project has none.",
      "swipe_cue": true
    },
    {
      "number": 3,
      "type": "build",
      "headline": "Same brain. Different system.",
      "body": "At work: sprint plans, deadlines, accountability. At home: a doc you opened once."
    },
    {
      "number": 4,
      "type": "build",
      "headline": "It's not about discipline",
      "body": "You don't white-knuckle your way through Q4. You have a system that makes shipping automatic."
    },
    {
      "number": 5,
      "type": "build",
      "headline": "But at home?",
      "body": "No sprint. No deadline. No one asking 'is this on track?' So it drifts."
    },
    {
      "number": 6,
      "type": "payoff",
      "headline": "You're not lazy.",
      "body": "You're operating without the infrastructure that makes you effective at work."
    },
    {
      "number": 7,
      "type": "payoff",
      "headline": "The diagnosis is wrong.",
      "body": "It was never a motivation problem."
    },
    {
      "number": 8,
      "type": "cta",
      "headline": "Send this to someone building something",
      "body": "@your-handle"
    }
  ],
  "caption": {
    "hook_125": "Your side project was ready to ship three features ago. You added another one anyway.",
    "body": "Same brain that manages a multi-million dollar roadmap can't get a landing page live.\n\nThat's not a character flaw. That's a systems failure.\n\nYou don't need more motivation. You need the same infrastructure that makes you lethal at work — applied to your thing.",
    "cta": "Send this to the friend who's been 'almost ready' for 6 months.",
    "seo_keywords": ["side project stuck", "side project motivation", "build in public"],
    "hashtags": ["#sideproject", "#buildinpublic", "#your-handle", "#buildyourthing"]
  }
}
```

**Caption rules (updated April 2026):**
- `hook_125`: first 125 chars, above the fold. No wasted words. No emoji as first character.
- `body`: 2-3 short paragraphs, max 150 words. Embed SEO keywords naturally.
- `cta`: single clear ask matched to pillar (share/save/convert).
- `hashtags`: 3-5 in caption after CTA. NOT in first comment. Algorithm changed in 2026.
```

### Secondary Output: Markdown Preview

Also output a readable markdown version for review:

```markdown
# Carousel: [Topic]
**Brand:** [brand] | **Pillar:** [pillar] | **Slides:** [N]

**Slide 1 (Hook):** [headline]
**Slide 2 (Context):** [headline] — [body]
**Slide 3 (Build):** [headline] — [body]
...
**Slide 10 (CTA):** [headline] — [body]

**Caption:**
[Full caption text]

**Hashtags:** [hashtag list]
```

## Instagram Platform Rules (Updated April 2026)

- **Slide 1 = grid thumbnail.** Must work standalone in 1:1 profile grid. Max 10 words.
- **Slide 2 includes swipe cue** — "the last one hits different" or similar curiosity hook.
- **Slide count by format:** 8-12 for educational, 6-8 for hot takes, up to 14 for story arcs. Don't pad to 10 if the content fits in 7.
- **Mid-carousel soft CTA** on slide 5-6 for 10+ slide carousels: "Save this — we're not done."
- **Last slide = CTA matched to pillar.** Mirror→share, Machine→save, Proof→convert. Never "follow for more."
- **Caption extends the carousel, doesn't summarize it.** Add context, backstory, or a different angle.
- **Hook must land in first 125 characters** of caption (Instagram fold). No emoji as first character.
- **Caption body embeds SEO keywords naturally** — Instagram search now indexes captions like Google.
- **Hashtags go IN THE CAPTION (3-5), after CTA. NOT in first comment.** Algorithm changed in 2026. Caption placement delivers ~30% better Explore distribution.
- **Never say "follow for more."** DM sends (#1 signal) > saves (#2) > comments > likes.
- **Music on carousels** pushes them into Reels feed. Add trending audio when publishing.
- **ALT text for Slide 1** — describe the visual for accessibility and discovery.

## Multi-Platform Specs (when repurposing beyond Instagram)

Folded in from the former social-media-carousel skill. Use when adapting Instagram carousel content for LinkedIn, X, or Facebook.

| Platform | Dimensions | Max slides | Aspect ratios |
|---|---|---|---|
| **Instagram** | 1080 × 1080 px | Up to 20 | 1:1 (default), 4:5, 16:9 |
| **LinkedIn** | 1080 × 1080 or 1080 × 1350 | Up to 20 | 1:1, 4:5 |
| **Twitter/X** | 1080 × 1080 px | Up to 4 | 1:1, 16:9 |
| **Facebook** | 1080 × 1080 px | Up to 10 | 1:1, 4:5 |

**Use 1080 × 1350 (4:5) on Instagram and LinkedIn** — takes more feed real estate than square. For TikTok carousels (still slides + text overlays via BlitzReels), see the `blitzreels-carousels-tiktok` skill.

## Quality Gates

Before delivering:

- [ ] **JSON is valid** — parses without errors, matches schema above
- [ ] **Framework selected** — pillar → framework mapping applied (PAS/AIDA/BAB)
- [ ] **Slide 1 hook ≤ 10 words** — readable at 161x200px thumbnail
- [ ] **All headlines ≤ 8 words**
- [ ] **All body text ≤ 25 words**
- [ ] **Slide 2 has a swipe cue** — curiosity hook, not just "Swipe →"
- [ ] **CTA matches pillar** — Mirror→share, Machine→save, Proof→convert
- [ ] **Mid-carousel CTA** on slide 5-6 if 10+ slides
- [ ] **Progressive narrative** — each slide builds, no random ordering
- [ ] **ONE idea per slide** — if a slide tries to say two things, split it
- [ ] **Every slide screenshot-able** — valuable on its own
- [ ] **Voice DNA compliance** — banned words absent, brand vocabulary present
- [ ] **No AI tells** — run the anti-AI checklist from voice DNA
- [ ] **Imperfection injected** — one human marker (aside, self-correction, uncertainty, specific detail)
- [ ] **Caption hook lands in first 125 chars** — no emoji as first character
- [ ] **Caption body has SEO keywords** — naturally embedded, not stuffed
- [ ] **Hashtags in caption (3-5)** — after CTA, NOT in first comment
- [ ] **The drunk text test** — read caption aloud, rewrite if it sounds like LinkedIn
- [ ] **The brand-distinctiveness test** — if you covered the @handle, could ANY business account have posted this? If yes, rewrite until it couldn't
- [ ] **The audience proxy test** — would a Staff Engineer at Stripe, mid-scroll at 11pm, stop and read Slide 1? If no, rewrite the hook
- [ ] **Archetype targeting** — can you name which specific archetype would screenshot this? If not, sharpen

## Post-Production AI-Tell Sweep (MANDATORY)

Before delivering, run this sweep on ALL output text:

1. **Number check:** Search for 47 (AI's favorite "random" number). Replace with a varied alternative. Ensure no number repeats across slides or across carousels in the same batch.
2. **Tool/reference diversity:** If you referenced the same tool (e.g., Notion) more than once, swap alternates: Figma, Vercel, Stripe, VS Code, Cursor, Linear, Railway, GitHub, Airtable.
3. **Parallel structure:** Break any run of 3+ items with identical sentence structure. Vary length, syntax, and rhythm.
4. **Voice DNA re-check:** Re-read the brand's banned vocabulary list. Flag any that slipped in.
5. **Handle check:** Use the correct Instagram handle from brand rules (e.g., @your-handle, NOT @welcome.to.mollywood).

This sweep is the last step before delivery. Do not skip it.

## Canva MCP Integration

The JSON output maps directly to Canva template text fields:

| JSON Field | Canva Text Field |
|------------|-----------------|
| `slides[0].headline` | `slide_1_headline` |
| `slides[1].headline` | `slide_2_headline` |
| `slides[1].body` | `slide_2_body` |
| ... | ... |
| `slides[9].headline` | `slide_10_headline` |
| `slides[9].body` | `slide_10_cta` |

The visual-producer agent reads this JSON and uses `perform-editing-operations` via Canva MCP to fill each field, then `export-design` to get PNGs.

## Input

1. **Topic or outline** — from `/repurpose`, `/content-matrix`, or raw topic
2. **Brand** — which brand (default: unstuck)
3. **Slide count** — 7-10 (default: 10)
4. **CTA** (optional) — specific call to action (default: brand's primary CTA)

## Output Location

Save to: `content-system/{brand}/content/YYYY-MM/carousel-[slug].json`

Also save the markdown preview alongside: `content-system/{brand}/content/YYYY-MM/carousel-[slug].md`

## Integration

- **Upstream:** Takes outlines from `/repurpose` or topics from `/content-matrix`
- **Downstream:** JSON feeds to visual-producer agent → Canva MCP → exported PNGs
- **Chains with:** `hooks` (Slide 1 options), Voice DNA (voice enforcement)
