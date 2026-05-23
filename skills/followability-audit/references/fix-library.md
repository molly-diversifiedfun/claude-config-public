# Fix Library — One Intervention Per Rung

For each affected rung, pick **the smallest possible intervention shippable in 48 hours**. Not a redesign. A single move. From The Followable System.

---

## UNDERSTAND fixes

When the rung is broken, people can't tell what the thing is or what to do next.

- [ ] **Rename something confusing.** A noun that's wrong is worse than a missing one.
- [ ] **Simplify the first screen.** Cut every element that isn't load-bearing for the first action.
- [ ] **Reorder the steps.** Often the "what is this" comes after "sign up." Reverse it.
- [ ] **Add a one-sentence story.** Three slots: what it is + who it's for + what you'll do with it. Fill in.
- [ ] **Cut one unnecessary option from the entrance.** Two doors is one too many.
- [ ] **Replace category jargon with outcome language.** "Holistic wellness platform" → "10-minute morning workouts."
- [ ] **Make the "for whom" explicit.** A vague audience reads as "not me."

---

## BELIEVE fixes

When the rung is broken, people don't trust the claim — for someone like them.

- [ ] **Add proof at the decision point.** A specific number, a real testimonial, a before-and-after. Where they hesitate, not on a separate page.
- [ ] **Add a rationale block** explaining *why* a constraint exists. ("This requires email because…")
- [ ] **Show what other people did.** Specific proof ("Sarah from Topeka shipped her course in 9 days using this") beats vague proof ("thousands of users").
- [ ] **Make the mechanism visible.** One sentence about *how* it works. Mystery erodes trust.
- [ ] **Add a try-before-commit option.** Sample, trial, preview, sandbox.
- [ ] **Surface social proof at the right altitude.** General audience trust ≠ specific use-case trust. Match the proof to the visitor's profile.
- [ ] **Add a safety claim.** "Free to leave," "no card required," "delete with one click" — proof of low risk.

---

## DO fixes

When the rung is broken, the first action is too big, too slow, or unclear.

- [ ] **Create a 5-minute first win.** Whatever they came for, give them a tiny taste of it before any setup.
- [ ] **Set better defaults.** Pre-fill anything you can. Decisions delay action.
- [ ] **Reduce inputs required before first value.** Each field is a chance to bounce.
- [ ] **Add a "do it now" button** that collapses three steps into one.
- [ ] **Move account creation to AFTER the first win.** Sign up is friction; deliver value first, capture later.
- [ ] **Show a working example before the blank canvas.** "Here's what one looks like" → "now you try."
- [ ] **Add a one-line cherry-pick path.** For sophisticated users: "Just want X? `command-here`."

---

## REPEAT fixes

When the rung is broken, people use it once and never come back.

- [ ] **Add a checkpoint.** "You've completed 3 of 10." Visible progress = motivation.
- [ ] **Send a progress signal.** Email, in-app, push — but earn it (not spam).
- [ ] **Build a "minimum day" option.** The smallest version of the behavior that still counts. Lower the bar on bad days.
- [ ] **Add a re-entry nudge after 3 days of silence.** Not a guilt trip — a ramp. "Welcome back. Pick up here:"
- [ ] **Define and communicate the cadence.** Daily? Weekly? Tell them. Predictability beats reminder fatigue.
- [ ] **Show streaks WITH safety nets.** Streak is motivating; streak-loss-on-one-miss is punishing. Build in "rest days."
- [ ] **Surface the next session before the current one ends.** Don't make them figure out what's next.

---

## SHARE fixes

When the rung is broken, the value stays locked inside private experience.

- [ ] **Generate a proof artifact** automatically. A receipt, a summary, a score, a snapshot.
- [ ] **Add a share prompt at the moment of completion.** Right when they feel the win, give them one tap.
- [ ] **Build a before-and-after capture.** Visual change = shareable.
- [ ] **Make the shared artifact compelling.** Bare text → branded card. Numbers → visual. Make it worth sharing.
- [ ] **Add a CTA for the viewer.** The share text should pull someone IN, not just describe the achiever.
- [ ] **Auto-fill the share copy.** Free-form composition is a friction wall.
- [ ] **Build a referral loop.** Sharer benefits + sharee benefits + visible loop = growth.

---

## Cross-rung anti-patterns

These bite multiple rungs. Watch for them.

- **Over-promising in the headline.** Inflates Believe via Understand, then crashes Do when the experience doesn't match.
- **Solving Share before Repeat.** Sharing a once-used thing isn't growth, it's noise.
- **Adding more "education" instead of fixing Understand.** Tutorials are a sign Understand is weak. Fix the thing, don't teach around it.
- **Adding more notifications instead of fixing Repeat's cadence design.** More pings won't fix a system with no rhythm.
- **Solving Believe with longer copy.** Longer doesn't mean truer. Specific does.

---

## Sequencing

When two rungs are both cracked:

1. Fix the lower one first (Understand < Believe < Do < Repeat < Share).
2. Ship one fix per rung, not five fixes per rung.
3. Re-audit after the fix. The lower rung's repair often raises the rung above it for free.
4. Don't ship Share fixes until Do is at 4+. People don't share something they couldn't use.

---

## Worked Examples — Real Interventions That Moved Scores

From real audits. Each is an instance of one of the fix categories above; included so you can see what the fix LOOKS like at implementation level.

### BELIEVE — "Proof at the decision point" via before/after artifact

**Context:** Public skill library README. Visitor lands, reads list of 25 skills, has no idea if they actually work.

**Fix shipped:** Inserted a "See One Work" section between the tagline and the skill list. Showed `humanize-ai-writing` actually run on a 78-word piece of generic AI marketing copy. Before-text + after-text + one line naming the diff (8 banned words killed, copulas restored, sentence length swung 3-17). No commentary, no claims — just the diff.

**Why it worked:** Mechanism + result + specifics all visible at the moment of decision. Beats any testimonial because the visitor sees the artifact, not someone else's report of the artifact.

**Pattern:** When the system produces an artifact that's 6-line-paste-able, the strongest BELIEVE fix is a before/after of the artifact. If you don't have a real production sample, generate the "before" deliberately (transparent provenance) — the fix is about showing the tool's work, not the tool's history.

### BELIEVE — Auto-updating social proof badges

**Context:** Same repo. No GitHub stars/last-commit visibility at top of README.

**Fix shipped:** 4 Shields.io badges in a row at the top — stars, license, last-commit, total-skills count. Used `style=flat-square` for visual consistency.

**Why it worked:** Costs nothing to add, auto-updates forever, gives "this is real and maintained" signal in 2 seconds. The total-count badge is manually maintained but worth it — communicates scale instantly.

### DO — "Start here" recommendation kills decision fatigue

**Context:** 25 skills in the same repo. Visitor decides to try one but doesn't know which.

**Fix shipped:** One line under the before/after demo: *"New to skills? Start with `humanize-ai-writing` — universal pain, instant payoff, hard to misuse."*

**Why it worked:** 25 choices = decision paralysis. Curating the entry point removes the choice without removing options. Pick the skill with (a) universal pain, (b) instant payoff, (c) hardest to misuse — those three filters are the canonical "start here" criteria.

### DO — Finish the install path through to first invocation

**Context:** Install instructions stopped at `cp -r skill-name ~/.claude/skills/skill-name`. Visitor copies the file and then... what?

**Fix shipped:** Added the actual invocation pattern after the cp command: *"Then in any session: 'Use the voice-extractor skill on these samples'"*. One line, but it closes the gap between install and first use.

**Pattern:** Audit the install instructions by literally following them as a new user. The gap between "file is on disk" and "feature is being used" is almost always missing in technical READMEs.

### REPEAT — CHANGELOG as re-entry trigger

**Context:** Repo with active releases but no visible "what's new" surface. Install once, forget forever.

**Fix shipped:** Three things together — (a) `CHANGELOG.md` with all batches dated newest-first, (b) 5th badge linking to the changelog, (c) "Recently Shipped" pinned block above the main list with the 3 most recent additions + dates.

**Why it worked:** Visible cadence + one-click access + always-current "what's new" view. Each new batch = a re-entry trigger.

### REPEAT — Star CTA naming the value

**Context:** Repo with no built-in mechanism for visitors to opt into updates.

**Fix shipped:** One line below the badges: *"⭐ Star to get notified when new skills land. New batches drop every few weeks."*

**Why it worked:** GitHub stars ARE a notification mechanism (users get repo update emails), but visitors don't think of it that way. Naming the value ("get notified") and the cadence ("every few weeks") converts passive viewers into subscribed-by-default ones.

### SHARE — Tweet-intent badge in the badge row

**Context:** Static repo with no built-in share path.

**Fix shipped:** Tweet-intent badge using the URL pattern `https://twitter.com/intent/tweet?text=ENCODED_PREFILL&url=REPO_URL`. Prefill names the value, not the title.

**Why it worked:** Free GitHub-native share path with prefilled copy that does the work for the sharer. The barrier went from "compose tweet" to "click button, edit if you want."

### SHARE — Specific channel + specific ask + specific reciprocation

**Context:** Generic "I'd love to hear what you build" pull at the bottom of the README.

**Fix shipped:** Replaced with: *"I want to see it. Open a [Discussion] and post what you shipped — what skill, what you used it for, what the output was. I'll share the best ones."*

**Why it worked:** Specific channel (Discussions, not "DM me"). Specific ask (3 named items: skill + use case + output). Specific reciprocation ("I'll share the best ones"). Removes every form of "but how?" friction.

### Cross-rung — Adjacent debt discovered during audit

**Context:** Auditing the repo for REPEAT/SHARE surfaced that 7 of 25 skills had no README — visitor clicking from the root README landed on a directory listing.

**Fix shipped:** Wrote 7 READMEs in one batch, each ~50-80 lines following the established 7-section pattern (problem → what it does → how to use → what makes it different → pairs with → license).

**Pattern:** Audits compound. Walking the user journey for one rung often surfaces broken primitives in adjacent rungs that weren't in the original scope. Don't defer them — fix in the same session if cheap.
