---
name: design-color-discipline
description: Unstuck brand color system — coral primary (#d1726b), cream backgrounds (#f9f7f6), locked color semantics, typography hierarchy
severity: warning
archetypes: [web-app, brand-content]
last-validated: 2026-05-26
---

**Color system:**
- Primary: warm coral `#d1726b` + cream backgrounds `#f9f7f6`
- NEVER use indigo/purple/cool-blue primary (shadcn default)
- Locked semantics: Coral = your voice / Gold = celebrations + page furniture / Sage = archive / Burgundy = canon (print only)
- Canonical reference: `~/github/unstuckwithmolly/public/brand-guide.md`

**Typography:**
- Body: Outfit Light (300)
- Headings: Cormorant Garamond Regular (400)
- Italic emphasis: `text-primary italic font-light` — NEVER italic + bold/semibold together
- Headline pattern: main statement + `<span class="text-primary italic font-light">emotional hook</span>`
- Bold: 1-2x per page max

**Why:** The shadcn default palette and font stack are the most common AI design tells. The locked color semantics prevent drift across pages.

**How to apply:** When building or editing any Unstuck-branded UI, check colors against this system. When in doubt, reference the brand guide.
