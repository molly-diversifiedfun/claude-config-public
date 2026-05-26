---
name: content-atomizer
description: Expert social media strategy and content atomization in one skill. Use when the user wants to create, schedule, or optimize social media content for LinkedIn, Twitter/X, Instagram, TikTok, Facebook, Threads, Pinterest, or other platforms — OR when they want to transform existing long-form content into platform-ready assets. Handles everything from single-post creation, content pillars, and hook writing, to transforming one pillar piece (essay, blog post, case study, talking point) into up to 19 cross-platform assets with a staggered release calendar. Operates in Brand Mode (6 Instagram/Reel derivatives with Voice DNA compliance, using Welsh's 1-3-5 extraction method and story angle selection) or Full Atomization Mode (19 assets: Twitter/X threads, LinkedIn carousels, TikTok scripts, email excerpts, podcast outlines, quizzes, infographics, and more). Chains with hooks and humanize-ai-writing for brand compliance. Triggers: social media, LinkedIn post, Twitter thread, tweet ideas, LinkedIn carousel, social media strategy, grow my following, content calendar, social scheduling, engagement, viral content, what should I post, repurpose this content, repurpose content, repurpose this, turn this into content, atomize for brand, content derivatives, 1 to many content, pillar to posts, atomize content, content atomizer, turn article into, repurpose article, content repurposing.
triggers:
  - social media
  - LinkedIn post
  - Twitter thread
  - tweet ideas
  - LinkedIn carousel
  - social media strategy
  - grow my following
  - content calendar
  - social scheduling
  - engagement
  - viral content
  - what should I post
  - repurpose this content
  - repurpose content
  - repurpose this
  - turn this into content
  - atomize for brand
  - content derivatives
  - 1 to many content
  - pillar to posts
  - atomize content
  - content atomizer
  - turn article into
  - repurpose article
  - content repurposing
allowed-tools: Read Write Edit Grep Glob WebSearch AskUserQuestion
---

<!-- Auto-inject brand config if available -->
Brand config: !`cat unstuck/brand-config.json 2>/dev/null || echo "No brand config found — using defaults"`

# Content Atomizer — Social Strategy & Platform-Ready Derivatives

Turn one pillar piece into up to 19 platform-ready assets, or build social content from scratch. Two core capabilities in one skill:

1. **Social Strategy Mode** — Create content from scratch: single posts, content pillars, hooks, platform-specific formats, engagement and analytics guidance
2. **Content Atomization** — Transform existing long-form content into derivatives:
   - **Brand Mode**: 6 brand-voice-matched Instagram/Reel assets (Voice DNA compliant)
   - **Full Atomization Mode**: 19 cross-platform assets with staggered release calendar

---

## Mode Selection

| Mode | When to Use | Output |
|------|-------------|--------|
| **Social Strategy** | Creating content from scratch; single posts, hooks, pillars | Platform-specific posts, calendars, hook variants |
| **Brand Mode** (default when brand config exists) | Instagram-first brand with Voice DNA on file | 6 derivatives: 3 Reels, 2 carousels, 1 static post |
| **Full Atomization Mode** | Multi-platform distribution, no brand constraint | 19 assets across social, video/audio, written, interactive |
| **Custom Mode** | User requests a specific subset | Whatever formats are requested |

If a `content-system/{brand}/{brand}-voice-dna.md` file exists → default to Brand Mode for repurposing requests.
If no brand config is found → default to Full Atomization Mode.
If user specifies formats or says "all platforms" → Custom or Full Atomization Mode.
If user is asking about social strategy, posting, or content from scratch → Social Strategy Mode.

---

## Before Starting

**Check for product marketing context first:**
If `.agents/product-marketing-context.md` exists (or `.claude/product-marketing-context.md` in older setups), read it before asking questions. Use that context and only ask for what's missing.

**If user pastes content and asks to repurpose or atomize it, proceed immediately.** Don't over-ask.

For Social Strategy Mode, gather this context if not provided:

### Goals
- What's the primary objective? (Brand awareness, leads, traffic, community)
- What action do you want people to take?
- Personal brand, company brand, or both?

### Audience
- Who are you trying to reach?
- What platforms are they most active on?
- What content do they engage with?

### Brand Voice
- What's the tone? (Professional, casual, witty, authoritative)
- Any topics to avoid?
- Any specific terminology or style guidelines?

### Resources
- How much time can you dedicate to social?
- Do you have existing content to repurpose?
- Can you create video content?

---

## Brand Mode Setup

**Step 1: Load brand context.** Read these files:

1. **Voice DNA**: `content-system/{brand}/{brand}-voice-dna.md`
2. **Brand rules**: `.claude/rules/brands/{brand}.md`
3. **Content strategy** (if exists): `content-system/{brand}/strategy.md`

If Voice DNA doesn't exist and user asked for brand-matched output, stop and tell them to run `voice-extractor` first.

**Step 2: Read the source content in full.** URL (via firecrawl), file path, or pasted text. Do NOT summarize or paraphrase before extracting.

---

## Platform Quick Reference

| Platform | Best For | Frequency | Key Format | Algorithm Priority |
|----------|----------|-----------|------------|-------------------|
| LinkedIn | B2B, thought leadership | 3–5x/week | Carousels, text posts | Dwell time, comments |
| Twitter/X | Tech, real-time, community | 3–10x/day | Threads, hot takes | Replies, quotes, bookmarks |
| Instagram | Visual brands, lifestyle | 1–2 posts + Stories daily | Reels, carousels | Saves, shares, watch time |
| TikTok | Brand awareness, younger audiences | 1–4x/day | Short-form video | Completion rate, shares |
| YouTube Shorts | SEO-driven video | 3–5x/week | Shorts, how-tos | Watch time, subscribe clicks |
| Facebook | Communities, local businesses | 1–2x/day | Groups, native video | Native content engagement |
| Pinterest | Evergreen traffic | Daily | Pins, idea pins | Saves, click-through |
| Threads | Authentic takes | 1–3x/day | Conversational posts | Replies, reposts |
| Podcast | Deep-dive expansion | Weekly | Episodes, audiograms | Completion, reviews |

**Universal 2025–2026 Trends:**
- "Follow for more" CTAs penalized across platforms
- Saves/bookmarks weighted higher than likes
- Completion rate matters more than views
- Native content outperforms cross-posted
- Carousels/threads outperform single posts

**For detailed platform strategies**: See [references/platforms.md](references/platforms.md)

---

## Content Pillars Framework

Build content around 3–5 pillars that align with expertise and audience interests.

### Example for a SaaS Founder

| Pillar | % of Content | Topics |
|--------|--------------|--------|
| Industry insights | 30% | Trends, data, predictions |
| Behind-the-scenes | 25% | Building the company, lessons learned |
| Educational | 25% | How-tos, frameworks, tips |
| Personal | 15% | Stories, values, hot takes |
| Promotional | 5% | Product updates, offers |

### Pillar Development Questions

For each pillar:
1. What unique perspective do you have?
2. What questions does your audience ask?
3. What content has performed well before?
4. What can you create consistently?
5. What aligns with business goals?

---

## Hook Formulas

The first line determines whether anyone reads the rest.

### Curiosity Hooks
- "I was wrong about [common belief]."
- "The real reason [outcome] happens isn't what you think."
- "[Impressive result] — and it only took [surprisingly short time]."

### Story Hooks
- "Last week, [unexpected thing] happened."
- "I almost [big mistake/failure]."
- "3 years ago, I [past state]. Today, [current state]."

### Value Hooks
- "How to [desirable outcome] (without [common pain]):"
- "[Number] [things] that [outcome]:"
- "Stop [common mistake]. Do this instead:"

### Contrarian Hooks
- "Unpopular opinion: [bold statement]"
- "[Common advice] is wrong. Here's why:"
- "I stopped [common practice] and [positive result]."

**For post templates and more hooks**: See [references/post-templates.md](references/post-templates.md)

---

## Quick Mode vs. Deep Mode (Atomization)

### Quick Mode (Default)
Atomize the content using the templates below. Fast, reliable, good for most use cases.

### Deep Mode
When the user asks for "optimized" or "researched" versions:
1. Use WebSearch to find top-performing content in their niche
2. Analyze current platform algorithm priorities
3. Customize hooks based on what's working now
4. Add platform-specific hashtag and timing recommendations

---

## Atomization Input

1. **Source content** — URL, file path, or pasted text
2. **Brand** — which brand (default: unstuck); omit for platform-agnostic atomization
3. **Mode** (optional) — Brand, Full Atomization, or Custom
4. **Target formats** (optional) — subset request (e.g., "just Reels," "no video")
5. **Audience context** (optional)
6. **Calendar context** (optional) — which pillar/date this is for

---

## What This Produces

**1 long-form piece → up to 19 platform-ready assets**

- 6 social (Thread, LinkedIn, IG, Short Post, Threads, Pinterest)
- 5 video/audio (Video, TikTok, Shorts, Audiogram, Podcast)
- 3 written (Email, Blog spin-offs, SEO snippets)
- 5 interactive/visual (Quiz, Discussion, Challenge, Infographic, Quotes)

Templates in `assets/`:
- `social-templates.yaml` — Twitter, LinkedIn, IG, Threads, Pinterest
- `video-audio-templates.yaml` — Video, TikTok, Shorts, Audiogram, Podcast
- `written-templates.yaml` — Email, Blog spin-offs, SEO snippets
- `interactive-templates.yaml` — Quiz, Discussion, Challenge
- `visual-templates.yaml` — Infographic, Quote graphics

### Social Formats (6)
| # | Format | Best For | Key Rule |
|---|--------|----------|----------|
| 1 | Twitter/X Thread | Big ideas, educational | First tweet = 90% of success |
| 2 | LinkedIn Carousel | Professional depth | Max 30 words per slide |
| 3 | Instagram Carousel | Visual learners | Save + Share focus |
| 4 | Short-Form Post | Quick wins | Under 100 char hook |
| 5 | Threads (Meta) | Authentic takes | No hard CTAs |
| 6 | Pinterest Pin | Evergreen traffic | Keyword in first 40 chars |

### Video & Audio Formats (5)
| # | Format | Best For | Key Rule |
|---|--------|----------|----------|
| 7 | Video Script (60s) | General short-form | Hook works with sound OFF |
| 8 | TikTok Script | Trend-driven content | Completion rate is everything |
| 9 | YouTube Shorts | SEO-driven video | First 2 lines of description matter |
| 10 | Audiogram Script | Podcast promotion | One idea only, 45 seconds |
| 11 | Podcast Outline | Deep-dive expansion | 15-20 min from one article |

### Written Formats (3)
| # | Format | Best For | Key Rule |
|---|--------|----------|----------|
| 12 | Email Excerpt | Newsletter/nurture | P.S. always gets read |
| 13 | Blog Spin-Offs | Content cluster SEO | 5 derivative articles |
| 14 | SEO Snippets | Featured snippet capture | Answer query in 40-60 words |

### Interactive & Community (3)
| # | Format | Best For | Key Rule |
|---|--------|----------|----------|
| 15 | Quiz/Poll | Engagement + education | Deploy across IG/LinkedIn/X |
| 16 | Discussion Prompts | Reddit/Discord/Slack | Question format, seed with your take |
| 17 | Challenge Prompt | UGC generation | You go first with example |

### Visual Assets - Copy Only (2)
| # | Format | Best For | Key Rule |
|---|--------|----------|----------|
| 18 | Infographic Outline | Designer handoff | Include chart type suggestions |
| 19 | Quote Graphics List | Social visuals | 5-10 standalone quotes |

## Atomization Process

### Step 1: Extract Core Elements

From the source content, identify:
- **Central thesis** - The one big idea (1 sentence)
- **Key insights** - 3-7 supporting points
- **Stories/examples** - Concrete illustrations
- **Data/stats** - Quotable numbers
- **Contrarian angles** - What goes against common belief
- **Actionable takeaways** - What reader can DO

### Step 2: Platform Mapping

| Element | Best Formats | Buyer Stage |
|---------|--------------|-------------|
| Central thesis | LinkedIn post, Video hook, Audiogram | Awareness |
| Key insights | Thread, Carousel, Podcast segment | Awareness/Consideration |
| Stories | TikTok, Video script, Discussion prompt | Awareness |
| Data/stats | Infographic, Pinterest, Quote graphic | Consideration |
| Contrarian take | Tweet, Threads, Reddit post | Awareness |
| Actionable takeaways | Email, Challenge, Quiz | Consideration/Decision |
| How-to steps | YouTube Shorts, Blog spin-off, Carousel | Decision |
| Social proof | Case study excerpt, Quote graphic | Decision |

### Step 2b: Buyer Journey Mapping

Map each asset to the customer journey:

```
AWARENESS (Top of Funnel)
├── Twitter/X Thread - hook with big idea
├── TikTok/Reels - pattern interrupt
├── Audiogram - quotable insight
├── Discussion prompts - start conversations
└── Threads post - authentic take

CONSIDERATION (Middle of Funnel)
├── LinkedIn Carousel - educational depth
├── Podcast outline - deep dive
├── Infographic - visual summary
├── Blog spin-offs - SEO capture
├── Quiz/Poll - engagement + education
└── YouTube Shorts - how-to snippets

DECISION (Bottom of Funnel)
├── Email excerpt - direct CTA
├── Pinterest pin - save for later
├── SEO snippets - capture search intent
├── Challenge prompt - activation
└── Quote graphics - social proof
```

**Strategy:** Release awareness content first, then consideration, then decision. Don't blast all at once.

### Step 3: Generate Assets

Create each format using the templates above. Customize hooks for each platform's audience.

## Quick Mode vs. Deep Mode

### Quick Mode (Default)
Just atomize the content using the templates. Fast, reliable, good enough.

### Deep Mode
When user asks for "optimized" or "researched" versions:
1. Use WebSearch to find top-performing content in their niche
2. Analyze current platform algorithm priorities
3. Customize hooks based on what's working NOW
4. Add platform-specific hashtag/timing recommendations

## Output Format

```markdown
# CONTENT ATOMIZATION: [Title]

## Source Summary
[1-2 sentence summary of original content]

## Central Thesis
[The one big idea]

## Key Insights Extracted
1. [Insight]
2. [Insight]
3. [Insight]
(etc.)

---

# SOCIAL FORMATS

## 1. TWITTER/X THREAD
[Full thread with numbering]

## 2. LINKEDIN CAROUSEL
[Slide-by-slide content]

## 3. INSTAGRAM CAROUSEL
[Slide-by-slide content]

## 4. SHORT-FORM POST
[Universal single post]

## 5. THREADS (META) POST
[Conversational thread]

## 6. PINTEREST PIN
[Title, description, visual concept]

---

# VIDEO & AUDIO FORMATS

## 7. VIDEO SCRIPT (60s)
[Full script with timing]

## 8. TIKTOK SCRIPT
[Platform-native with hooks]

## 9. YOUTUBE SHORTS DESCRIPTION
[SEO-optimized]

## 10. AUDIOGRAM SCRIPT
[45-second audio excerpt]

## 11. PODCAST EPISODE OUTLINE
[15-20 min expansion]

---

# WRITTEN FORMATS

## 12. EMAIL EXCERPT
[Complete email with subject options]

## 13. BLOG SPIN-OFF IDEAS
[5 derivative article concepts]

## 14. SEO SNIPPET VARIATIONS
[Featured snippet optimized]

---

# INTERACTIVE & COMMUNITY

## 15. QUIZ/POLL PROMPTS
[Questions and poll options]

## 16. DISCUSSION PROMPTS
[Reddit/Discord/community posts]

## 17. CHALLENGE PROMPT
[UGC activation]

---

# VISUAL ASSETS (Copy Only)

## 18. INFOGRAPHIC OUTLINE
[Structured for designer]

## 19. QUOTE GRAPHICS LIST
[5-10 pull quotes]

---

## DISTRIBUTION CHECKLIST

### Awareness Phase (Days 1-3)
- [ ] Twitter/X thread posted
- [ ] TikTok script recorded
- [ ] Audiogram created and shared
- [ ] Threads post published
- [ ] Discussion prompt seeded in community

### Consideration Phase (Days 4-7)
- [ ] LinkedIn carousel published
- [ ] YouTube Short uploaded
- [ ] Instagram carousel posted
- [ ] Podcast episode scheduled
- [ ] Quiz/poll launched
- [ ] Blog spin-off #1 drafted

### Decision Phase (Days 8-14)
- [ ] Email excerpt sent to list
- [ ] Pinterest pin published
- [ ] Challenge prompt launched
- [ ] SEO snippets added to original
- [ ] Quote graphics shared

---

## STAGGERED RELEASE CALENDAR

| Day | Platform | Asset | Buyer Stage | Optimal Time |
|-----|----------|-------|-------------|--------------|
| Day 1 | Twitter/X | Thread | Awareness | 9am or 12pm |
| Day 1 | TikTok | Video | Awareness | 7pm |
| Day 2 | Threads | Post | Awareness | 10am |
| Day 2 | Reddit/Discord | Discussion | Awareness | Evening |
| Day 3 | LinkedIn | Carousel | Consideration | 8am Tue-Thu |
| Day 4 | Instagram | Carousel | Consideration | 11am or 7pm |
| Day 5 | YouTube | Short | Consideration | 3pm |
| Day 5 | Podcast | Episode | Consideration | Release day |
| Day 7 | Email | Excerpt | Decision | Tue/Thu 10am |
| Day 7 | Pinterest | Pin | Decision | 8pm Sat |
| Day 10 | Twitter/X | Challenge | Decision | 12pm |
| Day 14 | Blog | Spin-off | Decision | Anytime |

**Staggered Release Strategy:**
- Never publish more than 2 platforms same day
- Space awareness → consideration → decision
- Repurpose top performer into more formats
- Week 2: Evaluate and double down on winners
```

## Platform Algorithm Notes (2025-2026)

| Platform | Algorithm Priority | What to Optimize |
|----------|-------------------|------------------|
| Twitter/X | Replies, quotes, bookmarks | Controversial hooks, question endings |
| LinkedIn | Dwell time, comments | First line hook, carousel saves |
| Instagram | Saves, shares, watch time | Reels completion, carousel swipes |
| TikTok | Completion rate, shares | First 2 seconds, save prompts |
| YouTube Shorts | Watch time, subscribe clicks | Hook + payoff loop |
| Pinterest | Saves, click-through | Keyword-rich descriptions |
| Threads | Replies, reposts | Authentic voice, no hard CTAs |
| Podcast | Completion, reviews | Strong intro, clear segments |

**Universal 2025-2026 Trends:**
- "Follow for more" CTAs penalized across platforms
- Saves/bookmarks weighted higher than likes
- Completion rate matters more than views
- Native content outperforms cross-posted
- Carousels/threads outperform single posts

## Quality Checklist

Before delivering, verify:

### Format Quality
- [ ] Each format uses platform-native conventions
- [ ] Hooks are DIFFERENT across platforms (not copy-paste)
- [ ] Video scripts are speakable (read aloud test)
- [ ] Carousels work standalone (no context needed)
- [ ] Audio scripts work with sound OFF (text overlays noted)

### Content Quality
- [ ] No AI-slop phrases ("In today's landscape", "Let's dive in", "Game-changer")
- [ ] Each piece has ONE clear takeaway
- [ ] CTAs are platform-appropriate (soft for TikTok/Threads, direct for email)
- [ ] Hooks create genuine curiosity, not clickbait

### Strategic Quality
- [ ] Assets mapped to buyer journey stages
- [ ] Staggered release calendar makes sense
- [ ] High-value formats prioritized (not just easy ones)
- [ ] Internal linking strategy for blog spin-offs

## What This Skill Does NOT Do

- **Design visuals** - Provides copy/outlines for infographics, not actual graphics
- **Schedule posts** - Provides content and timing guidance, not automation
- **Write the original** - Atomizes existing content only (use `content-writer` for original)
- **Record audio/video** - Provides scripts, not production
- **Post to platforms** - Provides content, user must publish

## When to Use This vs. Other Skills

| Use `content-atomizer` when... | Use other skills when... |
|-------------------------------|--------------------------|
| You have finished long-form content | Creating original content (`content-writer`) |
| Need multi-platform distribution | Single platform strategy (`linkedin-content`) |
| Want to maximize one piece's reach | Building content calendar (`content-calendar`) |
| Repurposing newsletters, articles | Writing from scratch (`viral-content`) |
| Need 15+ assets from one piece | Need just 1-2 quick posts |
| Strategic buyer-journey mapping | Quick social post (`hook-writer`) |
| Full atomization with calendar | Just need quote graphics |
