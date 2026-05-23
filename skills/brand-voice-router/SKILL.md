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
