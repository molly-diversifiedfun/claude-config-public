---
name: ai-design-tells
description: AI-generated designs (Lovable, v0, Cursor, Claude in TSX) converge on a recognizable aesthetic — gradient blob heroes, symmetric grids, indigo/purple palettes, gradient pill CTAs. Senior tech buyers clock it instantly. Catalog of visual + component + code patterns to AVOID, plus the canonical <your-first-brand> alternatives.
type: learned-pattern
applies-to: [design, frontend, marketing, ui]
projects: [all]
severity: warning
phase: [build, review]
last-validated: 2026-05-20
archetypes: [web-app, brand-content]
---

# Pattern: AI-Design Tells Avoidance

**Sister pattern to `ai-tell-avoidance.md`** (which covers content/copy tells). This file covers VISUAL + COMPONENT + CODE-LEVEL design defaults that mark a UI as "built by AI in 20 minutes."

## Why this matters

<your-first-brand>'s brand differentiator is the opposite of generic AI aesthetics: warm editorial, hand-drawn illustrations, "smart friend two drinks in" voice, anti-corporate. Every default AI-generated landing page (Lovable, v0, Cursor) leans the same direction — gradient blob heroes, symmetric 3-col features, indigo/purple palettes, "Trusted by" logo bars, pill CTAs with `→`. Senior tech buyers recognize this aesthetic and read it as: cheaply produced, indistinct, low-trust.

**Canonical reference:** `~/github/<your-web-app-1>/docs/ai-design-tells.md` (474 lines, 7 sections, 26-point checklist). This file is the brief always-loaded summary.

---

## The 26-point audit (score 0–2 per item)

### Layout & composition tells
1. Gradient blob hero (`absolute … blur-3xl` rounded shapes)
2. Symmetric 3-col or 2-col feature grids
3. `hover:-translate-y-1` on container-level elements
4. Centered-everything composition (no left-aligned editorial layouts)
5. "Trusted by N companies" logo bar
6. Uniform `rounded-2xl shadow-md` on every card

### Typography tells
7. Same `font-semibold` weight across hierarchy levels
8. Gradient `bg-clip-text text-transparent` on headings
9. All-caps eyebrow on every section (loses meaning past 3 uses)
10. Single-sentence-per-paragraph rhythm
11. Em-dash overuse — like decoration — everywhere

### Color tells
12. Cool blue / indigo / purple primary (the shadcn default)
13. Glassmorphism / frosted backgrounds (`bg-white/30 backdrop-blur-xl`)
14. Stock geometric/abstract imagery (squiggly arrows, 3D blobs)
15. Pure-black shadows everywhere (no warmth tint)

### Component tells
16. shadcn `<Card>` wrapping everything
17. Gradient pill CTAs with `→` in label text
18. Tabs/Accordions hiding primary content
19. Animated number counters on scroll
20. Framer Motion fade-up on every section

### Copy tells (overlap with ai-tell-avoidance)
21. Banned words (unlock / transform / empower / level up / manifest)
22. Vague benefit-stacking ("Save time. Save money. Make customers happy.")
23. "Don't take our word for it" testimonial transitions
24. "AI-powered" marketing when AI isn't the actual point

### Code-pattern tells
25. 10+ Lucide icons imported per file
26. Generic file names (FeatureSection, HeroBanner, CTABanner)

**Scoring:**
- 0–5: Clean. Ship.
- 6–12: Audit + iterate before shipping.
- 13+: Likely needs rebuilding with brand-driven design.

---

## The <your-first-brand> alternatives (what to do INSTEAD)

| AI default | <your-first-brand> alternative |
|-----------|---------------------|
| Gradient blob hero | Soft Pink Sketch illustration OR real product screenshot OR confident negative space |
| Symmetric N-col grid | Magazine-style asymmetric layout (1 dominant + 2 small, zigzag) |
| Hover-lift everywhere | Hover-lift only on primary CTAs; subtle underline elsewhere |
| Indigo/purple primary | Warm coral `#d1726b` + cream `#f9f7f6` (the <your-project-2>) |
| Glassmorphism | Solid warm backgrounds + subtle borders |
| Pill CTAs with `→` | Solid coral button, specific label ("Ship in 30 days — $159"), arrow as hover-animated element |
| Centered-everything | Left-aligned editorial layouts; centered reserved for hero h1 + final CTA |
| Trust bar logos | Real specific testimonials with names + outcomes |
| Same `font-semibold` | Body Light (300) / Heading Regular (400) / italic emphasis font-light |
| Single-word sentence rhythm | Mixed paragraph lengths; punchlines work because the rest has texture |

---

## Enforcement

1. **Pre-merge audit:** every UI commit reviewed against the 26-point checklist
2. **Marketing graphic audit:** every product image / social post / cover graphic scored before publishing
3. **Skill chain:** when using `frontend-design` / `ui-ux-pro-max` / similar code-gen skills, pre-load this file as context
4. **Voice chain:** when generating UI copy via `copywriting` / `direct-response-copy`, run output through `humanize-ai-writing` AND check against tells #21-#24

## The 1-sentence rule

**If you can't tell which company built this from the design alone, rebuild it until you can.**

That's the test. The <your-first-brand> brand only works if the visual identity is unmistakable. AI-default aesthetics fail that test by design.
