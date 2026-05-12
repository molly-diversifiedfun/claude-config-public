---
name: repurpose
description: Turn one pillar piece (essay, blog post, case study, talking point) into 6 platform-ready content derivatives — 3 Reel scripts, 2 carousel outlines, 1 static post — all voice-matched via Voice DNA. Uses Welsh's 1-3-5 method (extract core, then generate per-platform). Chains with hooks and humanize-ai-writing for brand compliance.
triggers:
  - repurpose content
  - repurpose this
  - turn this into content
  - atomize for brand
  - content derivatives
  - 1 to many content
  - pillar to posts
allowed-tools: Read Write Edit Grep Glob
---

<!-- Auto-inject brand config if available -->
Brand config: !`cat unstuck/brand-config.json 2>/dev/null || echo "No brand config found — using defaults"`

# Repurpose — Brand Voice Content Derivatives

Turn one pillar piece into 6 platform-ready derivatives, all matching brand voice.

## Before Repurposing

**Step 1: Load brand context.** Read these files:

1. **Voice DNA**: `content-system/{brand}/{brand}-voice-dna.md`
2. **Brand rules**: `.claude/rules/brands/{brand}.md`
3. **Content strategy** (if exists): `content-system/{brand}/strategy.md`

If Voice DNA doesn't exist, stop and tell the user to run `voice-extractor` first.

**Step 2: Read the source content.** Read the full piece — URL (via firecrawl), file path, or pasted text. Do NOT summarize or paraphrase before extracting.

## The Two-Pass Method (Welsh's 1-3-5)

### Pass 1: Extract Core Elements

From the source content, extract:

| Element | What to Extract | Example |
|---------|----------------|---------|
| **Central thesis** | The ONE big idea (1 sentence) | "You don't have a motivation problem. You have an infrastructure problem." |
| **Key insights** | 3-7 supporting arguments | Each one a standalone point |
| **Stories/examples** | Concrete illustrations with specific details | "<your unlaunched-thing example>," "<your signature project>" |
| **Data points** | Specific numbers, stats, research | "76% of regrets," "$2,400 in the first month" |
| **Contrarian angles** | What goes against common belief | "Bigger timelines don't mean better outcomes" |
| **Actionable takeaways** | What the reader can DO | "Cut your scope to 5 features" |
| **Quotable lines** | Sentences that stand alone as mic-drops | "Same brain. Same skills. Completely different infrastructure." |

### Pass 1.5: Story Angle Selection (for story-based source content)

If the source content is a signature story or case study, select angles BEFORE generating formats. Each angle reframes the same story for a different content purpose:

1. **THE SHAME ANGLE** — Makes the audience feel uncomfortably seen. Focuses on the gap between professional competence and personal stalling. Opens a wound gently.
2. **THE SYSTEMS ANGLE** — Diagnoses WHY the story happened using infrastructure language. Reframes from personal failure to systems failure. PM vocabulary: roadmap, sprint plan, scope, accountability, ship date.
3. **THE "YOUR TEAM WOULD NEVER" ANGLE** — Professional contrast. "You'd never let your team operate without X — so why are you doing it to yourself?" Leverages their professional identity against their personal stalling pattern.
4. **THE OBJECTION-KILLER ANGLE** — Maps the story to a common objection (time, cost, "I should figure it out myself," "is this coaching," "bad timing"). The story becomes proof that the objection is a stall pattern.
5. **THE COLD-TRAFFIC HOOK ANGLE** — Optimized for people who've never heard of the brand. No brand context needed. Pure pattern recognition: "If you've ever [done this thing], this post is for you."

Assign one angle per derivative. Not all derivatives need a story angle — but at least 3 of the 6 should use one when the source is story-based.

### Pass 2: Generate Per-Platform

Using the extracted elements, generate exactly 6 derivatives:

---

### Derivative 1-3: Reel Scripts (60-90 seconds each)

Each Reel script must:
- Cover ONE insight from the source (not a compressed summary of the whole piece)
- Follow the pattern: **Hook (3 sec) → Problem (10 sec) → Insight/Reframe (30 sec) → CTA (10 sec)**
- Include filming notes: energy level, tone shifts, look-at-camera moments
- Be speakable — read naturally aloud, not like written prose
- Use contractions, fragments, and conversational rhythm

**Reel Script Format:**
```markdown
### Reel [N]: [Working Title]
**Duration:** ~[N] seconds
**Insight used:** [which extracted insight]
**Hook type:** [contrarian/problem-first/surprising-fact/story-open/unpopular-opinion]

---

**HOOK (0-3 sec)**
[Exact words to say — this is what stops the scroll]

**PROBLEM (3-15 sec)**
[Set up the pain point. Be specific. Name the situation.]

**INSIGHT (15-50 sec)**
[The reframe or teaching moment. This is the meat.]

**CTA (50-60 sec)**
[Specific next step. Not "follow for more." Map to a real conversion point.]

---

**Filming Notes:**
- Energy: [calm/medium/high]
- Tone: [conversational/authoritative/vulnerable]
- Camera: [talking head / walk-and-talk / sit-down]
- Look-at-camera moments: [when to break fourth wall]
- B-roll suggestions: [if any]
```

**Post-Production AI-Tell Sweep (run on ALL 6 derivatives):**
1. No repeated "random" numbers (especially 47). Vary across derivatives.
2. Tool/reference diversity — rotate Figma, Vercel, Stripe, VS Code, etc. Don't default to Notion.
3. Handle check — use correct brand handle.
4. No parallel sentence structure across derivatives.

**Rules for the 3 Reels:**
- Each uses a DIFFERENT insight from the source
- Each uses a DIFFERENT hook type (from the 5 frameworks)
- No two Reels make the same argument

---

### Derivative 4-5: Carousel Outlines (7-10 slides each)

Each carousel outline must:
- Cover ONE theme from the source (different from the Reels)
- Follow progressive narrative (each slide builds)
- Slide 1 = hook, Slides 2-9 = content, Final slide = CTA

**Carousel Outline Format:**
```markdown
### Carousel [N]: [Working Title]
**Slides:** [N]
**Theme:** [which extracted element this covers]
**Hook type:** [from 5 frameworks]

| Slide | Type | Headline (≤8 words) | Body (≤25 words) |
|-------|------|--------------------|--------------------|
| 1 | hook | [scroll-stopping headline] | |
| 2 | content | [point 1] | [supporting detail] |
| 3 | content | [point 2] | [supporting detail] |
| ... | ... | ... | ... |
| [N] | cta | [action headline] | [specific CTA with URL/handle] |

**Caption:** [Instagram caption, under 2200 chars, with line breaks]
**Hashtags:** [15-20 relevant hashtags]
```

---

### Derivative 6: Static Post

One static Instagram post:
- Caption under 2200 characters
- 5 hook variants (generated via `/hooks` framework — one per type)
- 15-20 hashtags
- The hook variants are for A/B testing — the user picks one

**Static Post Format:**
```markdown
### Static Post: [Working Title]
**Insight used:** [which extracted element]

**Hook Variants:**
1. **Contrarian:** [hook]
2. **Problem-first:** [hook]
3. **Surprising fact:** [hook]
4. **Story-open:** [hook]
5. **Unpopular opinion:** [hook]

**Caption (after hook):**
[Rest of the caption — the teaching/story/reframe]

[Line break]

[CTA — specific next step]

**Hashtags:**
[15-20 hashtags]
```

## Instagram Platform Rules (2025-2026)

These rules apply to ALL output. Non-negotiable.

### Captions

- **First 125 characters are everything.** Instagram truncates at ~125 chars in feed view. The hook MUST land before the fold.
- **Reel captions complement the video, they don't repeat it.** The person just watched the Reel — the caption adds context, backstory, or a different angle. Never transcribe the script into the caption.
- **Carousel captions extend the teaching.** Add value beyond what's on the slides. Don't summarize the carousel.
- **Line breaks for scannability.** One thought per paragraph. Use dot separators (.) or blank lines between sections.
- **CTA near the end, before hashtags.** One clear action. Map to: link in bio, DM me [keyword], save this, share with someone who needs it.
- **Never say "follow for more."** Algorithm penalizes it. Use save/share CTAs instead — saves are weighted 3-5x higher than likes.

### Hashtags

- **Hashtags go IN THE CAPTION (3-5), after CTA. NOT in first comment.** Algorithm changed in 2026. Caption placement delivers ~30% better Explore distribution.
- **3-5 hashtags max.** Caption keywords matter more than hashtag volume now. Embed SEO keywords naturally in caption body.
- **Priority tags:** #sideproject #techcareers #shipitdontthinkit plus 1-2 niche tags relevant to the post topic.

### Reels

- **Hook in first 3 seconds** — visual + text overlay + spoken word must all align
- **Text overlays are mandatory** — most viewers watch with sound off. Key lines need on-screen text.
- **Completion rate > views.** Keep it tight. 60 seconds beats 90 seconds for retention.
- **Cover image matters** — it lives in the grid. Must be visually compelling at thumbnail size.
- **End screen:** Don't fade to black. End on the CTA or a strong visual.

### Carousels

- **Slide 1 = the grid thumbnail.** It must work as a standalone image in the 1:1 profile grid.
- **Slide 2 should include a swipe cue** — "Swipe →" or an arrow. Most people don't swipe without prompting.
- **7 slides is the engagement sweet spot.** 10 is the max. More isn't always better.
- **Last slide = CTA + save prompt.** "Save this for later" or "Share with someone building something." Saves are the top algorithm signal.
- **4:5 ratio (1080x1350) gets more screen real estate** than 1:1 in feed. But 1:1 is safer for grid consistency. Use whatever matches the Canva template.

### Static Posts

- **4:5 ratio preferred** for maximum feed real estate
- **ALT text is required** — describe the image for accessibility. Instagram rewards ALT text in discovery.
- **Save-bait framing:** If the post teaches something, frame it as reference material ("Save this checklist," "Bookmark this framework").

### Algorithm Signals (Priority Order)

1. **Saves** — strongest signal. "Save this" CTAs work.
2. **Shares** — DM shares and story shares. "Share with someone who..." CTAs.
3. **Comments** — genuine comments, not emoji-only. Ask specific questions.
4. **Watch time / swipe depth** — completion rate for Reels, swipe-through for carousels.
5. **Likes** — weakest signal. Don't optimize for likes.

---

## Quality Gates

Before delivering, verify:

- [ ] **Each derivative stands alone** — no "as I mentioned in the essay" references
- [ ] **Voice DNA compliance** — re-read each piece against the Critical Rules
- [ ] **No AI tells** — no filler transitions, no "Let's dive in," no "Here's the thing about"
- [ ] **Hook variants are genuinely different angles** — not rewording of the same hook
- [ ] **Reel scripts are speakable** — read aloud test
- [ ] **Reel captions DON'T repeat the script** — they complement
- [ ] **Carousel headlines ≤ 8 words** per slide
- [ ] **Carousel body ≤ 25 words** per slide
- [ ] **Carousel slide 2 has a swipe cue**
- [ ] **Last carousel slide has save/share CTA**
- [ ] **Each derivative uses a DIFFERENT source element** — no overlap
- [ ] **Brand vocabulary enforced** — required terms used, banned terms absent
- [ ] **CTAs map to real conversion points** — never "follow for more"
- [ ] **Hashtags in caption (3-5)** — after CTA, NOT in first comment (2026 algo change)
- [ ] **Caption hook lands in first 125 characters**
- [ ] **ALT text provided** for static posts and carousel cover slides

## Input

1. **Source content** — URL, file path, or pasted text
2. **Brand** — which brand (default: unstuck)
3. **Target formats** (optional) — can request subset (e.g., "just Reels" or "just carousels")
4. **Calendar context** (optional) — which pillar/date this is for

## Output

Save all derivatives to: `content-system/{brand}/content/YYYY-MM/repurpose-[slug].md`

Include metadata at the top:
```markdown
---
source: [file path or URL of original]
brand: [brand name]
date_generated: [YYYY-MM-DD]
status: draft
derivatives: 3 reels, 2 carousels, 1 static
---
```

## Integration

- **Upstream:** Called after `/content-matrix` assigns topics, or manually with any pillar content
- **Downstream:** Carousel outlines feed to `/carousel-writer` for structured JSON, Reel scripts go to Molly for filming
- **Chains with:** `hooks` (hook generation), Voice DNA (voice enforcement), `humanize-ai-writing` (quality pass)
- **References:** `content-atomizer` for broader platform coverage beyond Instagram focus
