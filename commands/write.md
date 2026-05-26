Content mode — loads writing skills and brand voice for any content work.

Usage: /write [content description]

Flow:
0. **Pre-flight — query MemPalace (NEW Phase 3):**
   - `mcp__mempalace__mempalace_search` for the topic + brand (e.g., "unstuck book chapter", "outline portfolio copy")
   - Filter by brand wing — fail open per `feedback_mempalace_wing_filter_error_finding_id.md`
   - Pull: voice DNA captures, past performance for similar content type, rejected directions for this brand, banned-phrases evolution, prior series parts (for multi-part work)
   - Surface 3-5 drawers to the user: "Loaded [paths] for voice + prior context"
   - Route to @content-social / @content-longform / @content-business based on length; each has its own pre-flight as backup (Phase 2)
1. Skill collections + brand voice rules load (brand-voice-router runs FIRST in delegated agent)
2. humanize-ai-writing runs on ALL output (non-negotiable)
3. @market-researcher fact-checks if needed
4. MoA council consulted for positioning/messaging decisions
5. @project-manager tracks
6. @content-qa runs before declaring done (hard gate)

Content types this handles:
- Book chapters (loads non-fiction-book-factory skills)
- Blog posts and newsletters
- Product copy (headlines, CTAs, descriptions)
- Documentation (READMEs, changelogs, API docs)
- Email sequences
- Social media content

Example: /write Chapter 7 voice pass for The <your-project-2>
Example: /write blog post about shipping faster as a solopreneur
Example: /write product description for GiftShopper premium tier
