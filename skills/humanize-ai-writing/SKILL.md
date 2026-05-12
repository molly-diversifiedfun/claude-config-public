---
name: humanize-ai-writing
description: Strip AI patterns from any written content and make it sound like a real human wrote it. Use this skill whenever the user says anything like "make this sound human," "this sounds like AI," "de-AI this," "make it sound like me," "humanize this," "this sounds robotic," "rewrite this naturally," "this reads like ChatGPT," "remove AI tells," "AI fingerprint," "make it less AI," "sound more natural," or any variation of wanting content to feel authentic and human-written rather than machine-generated. Also trigger when reviewing any draft, copy, script, email, DM, social post, or marketing content where the user hasn't explicitly asked for humanization but the output clearly contains AI patterns. If the user has a brand voice skill active, combine this skill with that voice. This skill is about the WAY writing sounds, not WHAT it says. NOT for rewriting from scratch — that destroys voice. NOT for editing human-written text — use precision-editor for that.
---

# Humanize AI Writing v3

## Why AI Text Gets Caught

Detectors measure two core signals: **perplexity** (how predictable each word choice is) and **burstiness** (how much sentence length varies). AI scores low on both because every token converges toward the most statistically likely next word. The result reads like the average of everything on the internet — technically correct, stylistically dead.

Modern detectors (GPTZero, Originality.ai, Pangram Labs) now go far beyond those two signals. They use multi-model classifiers trained on outputs from specific LLM families. Claude, GPT, Gemini, and Llama each leave distinct **stylistic fingerprints** that survive prompting tricks, custom writing styles, and even manual editing — unless you break the underlying structural patterns.

This skill targets those structural patterns. Not surface swaps.

**Goal:** Remove the machine fingerprint so the text stops *feeling* AI-generated to human readers. Not to fool detectors (they're unreliable).

---

## Hard Rules — Never Violate

These rules protect the user's voice. Read them before every invocation.

- **Change fewer than 20% of sentences.** Rewriters make text worse 74% of the time (Masrour et al., ACL 2025). If you're changing more, something is wrong — stop and reassess.
- **Surgical editing, not rewriting.** Preserve the author's sentence structure, argument order, and examples unless they are themselves AI tells. The output should be recognizable as the user's own text with targeted fixes.
- **Never add deliberate errors.** Typos, grammatical mistakes, fake "um"s, forced slang — this is the Undetectable.ai failure mode. Degrades quality without fooling anyone.
- **Co-occurrence, not word bans.** One "robust" is not a tell. Three AI-associated words clustered within 200 words is. Single-word flags produce unacceptable false positives on ESL writers, academic writers, and formal prose.
- **Respect the genre.** Academic tolerates hedging. Creative tolerates fragments. Social tolerates almost nothing from the AI playbook. Always use genre-specific thresholds.
- **Never remove human signals.** Contractions, first-person pronouns, personal anecdotes, sentence fragments, informal punctuation — these are HUMAN signals. Preserve them if present; consider adding them if absent.
- **Em dashes aren't the enemy.** 1-2 per 500 words is normal human usage. Only flag excess density alongside other tells.

---

## Two Operating Modes

**Interactive mode** (default when a user pastes text and asks for humanization): run Pass 0 (genre + annotated report + user approval) before any edits.

**Pipeline mode** (when invoked downstream of brand-voice-router or another producer in a content pipeline, with no human in the loop): skip Pass 0, apply Pass 1 + Pass 2 directly using `blog` genre defaults unless metadata specifies otherwise.

Detect mode from context: if the conversation has a human user actively reviewing, run interactive. If invoked autonomously by an agent or chain, run pipeline.

---

## PASS 0 — Genre + Annotated Report (interactive mode only)

### Step 1: Genre preset

Ask:

> **What's the genre?**
> (a) Blog post  (b) Business / email / report  (c) Academic  (d) Creative fiction  (e) Social media
>
> This adjusts what gets flagged. Academic writing tolerates more hedging. Creative writing has a lower threshold for AI vocabulary. Pick the closest match.

If the user already specified genre in their message, skip the question. Store the genre — it controls every threshold in `references/tell-taxonomy.md`.

### Step 2: Annotated detection report

Scan the user's text against the taxonomy. Scan order matters (structural and rhythm first):

1. **Rhythm** — sentence-length variation, sterile perfection
2. **Structure** — summary paragraphs, heading inflation, list overuse, tricolons, parallel construction
3. **Vocabulary** — cluster detection (3+ co-occurring words), hedging phrases, elegant variation
4. **Transitions** — stacked formal transitions, "Let's explore" patterns
5. **Punctuation** — em dash density
6. **Semantic** — false balance, signposting, cliche openers (flag only if Tier 1/2 tells already present)

Present findings in this exact format:

```
## AI Tell Report

**Overall AI Signature: [None / Low / Medium / High]**
([N] patterns detected across [N] categories)

### Flagged Patterns
1. **[CATEGORY]** Lines [X-Y]: [What was detected and why].
   Confidence: [High / Medium].
   → Suggested fix: [Show exact before and after.]

[Continue for all flagged patterns]

### Passed (not flagged)
- [Category]: [Brief reason it passed]
```

Rules: number every flag, always state CATEGORY in brackets (VOCABULARY CLUSTER / RHYTHM / STRUCTURE / TRANSITION / PUNCTUATION / SEMANTIC / OPENING), always include confidence, every flag MUST have a specific replacement (not "consider revising"), build trust with the "Passed" section.

Severity scale: High = 3+ categories. Medium = 2. Low = 1. None = no flags.

### Step 3: User approves fixes

Ask:

> **How do you want to proceed?**
> (a) Apply all fixes
> (b) Review each fix individually
> (c) Apply all except [list numbers to skip]

Wait for response. Do not apply any fixes until instructed. If (b), present each fix with before/after and ask y/n.

---

## PASS 1 — Audit and Rewrite

Apply the user-approved fixes (interactive mode) OR run all seven checks (pipeline mode). They compound — run in order.

### 1. Strip Claude-Specific Fingerprints

Claude leaves model-specific tells that other LLMs don't share. Kill these first.

- **Thoughtful qualifiers:** "I think," "it seems," "from my understanding," "it's worth noting," "broadly speaking" — delete or replace with direct statements.
- **Balanced-perspective reflex:** "While some argue X, others contend Y" — if you have a position, state it. No false balance.
- **Ethical insertion:** Reflexive caveats about responsible use or limitations — strip unless content genuinely requires them.
- **Helpful disclaimers:** "This is a complex topic," "results may vary," "it's important to consult a professional" — delete unless legally necessary.
- **Structured over-organization:** Headers, numbered lists, bullets in DMs/emails/social/scripts — strip all structural formatting in conversational content.
- **The warmth pattern:** "That's a great question," "Absolutely!", "I hope this helps," "Let me know if you'd like me to expand" — delete all openers and closers.

### 2. Kill AI Vocabulary

Consult `references/kill-list.md` for tiered list AND `references/tell-taxonomy.md` for confidence ratings.

- **Tier 1 (Always flag):** delve, leverage, utilize, robust, comprehensive, multifaceted, pivotal, seamless, tapestry, landscape (metaphorical), moreover, furthermore.
- **Tier 2 (Flag when clustered):** foster, illuminate, crucial, dynamic, innovative, catalyst, trajectory, spectrum — only when 3+ appear in the same section.
- **Tier 3 (Flag at density):** significant, effectively, potential, approach, framework, context, enhance.

Era-specific:
- 2023-era (GPT-4): delve, tapestry, testament, vibrant, intricate, meticulous
- 2024-era (GPT-4o): fostering, showcasing, highlighting, bolstered, align with
- 2025+ (GPT-5): emphasizing, enhance, highlighting, showcasing
- Claude-specific: nuanced, straightforward, genuinely, I'd be happy to

### 3. Fix Structural Patterns

Shapes, not words. Can't ctrl+F for these.

- **Copula avoidance:** "serves as," "functions as," "acts as," "features," "boasts" → "is" / "has."
- **Significance inflation:** "pivotal," "watershed," "transformative" → state the fact, cut the claim.
- **Present participial clause-endings:** "...highlighting the need for continued innovation," "...underscoring the significance" — top detection signal. Cut.
- **Formulaic challenges/future section:** "Despite challenges... continues to thrive" → be specific or cut.
- **Hourglass structure:** Synthesis → details → synthesis. Vary. Start mid-argument. End abruptly.
- **Even paragraphing:** Equal-length paragraphs create visual symmetry detectors flag. Vary dramatically.
- **Negative parallelisms:** "It's not just X — it's Y" — state the point directly.
- **The rule of three:** "Smart, strategic, and scalable" — vary. Use 2, 4, or 1.

### 4. Fix Rhythm (Burstiness)

AI averages ~27 words per sentence with minimal variance. Humans swing between 3-word fragments and 40-word run-ons.

- No two consecutive sentences within 5 words of each other in length
- At least one sentence under 5 words per paragraph
- At least one sentence over 25 words per section
- Start at least one sentence with "And" or "But"
- Use a fragment for emphasis at least once
- Break a grammar rule intentionally at least once
- Vary paragraph length: some 1 sentence, some 6+

### 5. Replace Generality with Specificity

AI generalizes. Every vague reference is a flag. Every specific detail is proof of a person.

- "a popular tool" → name it (Notion, Figma, Linear)
- "a recent study" → name the study + year
- "industry experts" → name one person or org
- "a significant amount" → state the number
- "various stakeholders" → name who
- Add at least one detail per section only someone present would know.

### 6. Inject Voice and Opinion

- State at least one unhedged opinion ("This is wrong" not "Some might consider this suboptimal")
- Include a parenthetical aside or "but I digress"
- Switch emotional register at least once
- Write one sentence you'd actually say at a bar
- Add self-deprecation, sarcasm, or dry humor where supported
- If a brand voice exists (check brand-voice-router), apply it here

### 7. Kill Remaining Formatting Tells

- **Em dashes:** Max 1 per 500 words. Replace with periods, commas, or restructure.
- **Synonym cycling:** "platform → solution → ecosystem → framework" — pick one word, repeat it.
- **Boldface in conversational content:** Strip in DMs, emails, social posts, scripts.
- **Curly quotes:** Normalize to straight quotes.
- **Hyphenated word pair clustering:** Max 2 per paragraph.
- **Title Case in headings:** Use sentence case.

---

## PASS 2 — Residual Audit

Read the rewrite fresh as a skeptical human reader, not mechanically against the taxonomy. Ask: **"What still feels AI-generated?"**

The second pass catches:
- Structural patterns only visible after vocabulary fixes (the "uncanny valley")
- Rhythm problems created by the first-pass edits themselves
- Patterns the taxonomy doesn't cover

Specific survivals to check:

1. **Recycled transitions:** Did "moreover" become "additionally" become "furthermore"? All three are AI tells.
2. **Lingering copula swaps:** "serves as" → "functions as" → "acts as"? Still AI. Use "is."
3. **Inflation creep:** Cut "groundbreaking" but introduced "transformative" or "game-changing"? Same problem.
4. **Rhythm relapse:** Read aloud. Sentence lengths re-flatten?
5. **Emotional flatline:** "What surprised me most was..." without earning it? Cut.
6. **Chatbot artifacts:** "I hope this helps," "Feel free to," "Great question" survivors? Delete.
7. **Template phrases:** "A [adj] step towards [adj] [noun]" — instant tell.
8. **Filler phrases:** "In order to" → "To." "Due to the fact that" → "Because."
9. **Generic conclusions:** "The future looks bright," "Only time will tell" — cut.
10. **Cutoff disclaimers:** "While specific details are limited..." — find the info or remove.

If Pass 2 finds 3+ surviving patterns, run Pass 1 again before delivering.

In interactive mode, present Pass 2 findings as a second annotated report and ask for approval before applying.

---

## Output (interactive mode)

Deliver the final edited text. Offer:

> **Want a diff view?** I can show exactly what changed, line by line.

If yes, show before/after with strikethrough for removed and bold for added.

---

## Content-Type Quick Reference

### DMs / Text Messages
- 1-3 sentences per message. No transitions. One thought per message.
- Lowercase where natural. Abbreviations fine. Zero formatting.

### Social Posts / Captions
- Start mid-thought, not "In today's..."
- One emoji max. No hashtag stuffing. Write like a group chat. End with a real question or half-thought.

### Emails
- Open with the point. No "I hope this finds you well."
- One ask. End with a specific request, not "Please don't hesitate to reach out."

### Sales Copy / Scripts
- Real numbers, names, stories. Specific about who this is NOT for.
- State price without flinching.

### Long-Form (Articles, Guides, Docs)
- Vary section lengths dramatically.
- Same word for the same thing. Don't cycle synonyms.
- Include a personal observation breaking the analytical register.

### LinkedIn Posts
- No "I'm thrilled to announce." Start with insight or tension.
- One line per paragraph, but vary. End with a genuine question.

---

## What NOT to Do

- Don't just add contractions and call it human. Surface-level.
- Don't over-correct into chaos. Natural, not sloppy.
- Don't add fake typos or "um"s. Cosplay.
- Don't swap AI words for simpler synonyms while keeping the same structure. Structure IS the problem.
- Don't use AI-humanizer tools or paraphrasers. Detectors are now trained on humanizer outputs specifically.
- Don't assume one pass is enough.
- Don't edit human-written text with this skill. Use precision-editor.

---

## Integration with Other Skills

- **brand-voice-router** — Apply brand-specific voice AFTER humanization. Humanize fixes structure; brand voice fixes personality.
- **voice-extractor** — Load the user's voice profile first. Fixes will match the user's natural style.
- **precision-editor** — Different tool for human text at configurable edit levels.

---

## Reference Files

- `references/kill-list.md` — Complete tiered vocabulary kill list with era-specific tracking and replacement tables.
- `references/tell-taxonomy.md` — Full detection catalog with confidence ratings and genre-specific thresholds. Consult during Pass 0 Step 2 scan.
