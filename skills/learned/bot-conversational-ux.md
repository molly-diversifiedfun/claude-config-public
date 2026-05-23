---
name: bot-conversational-ux
description: Cross-bot UX patterns for your Telegram products (<your-personal-ai-project>, <your-agent-project>/<your-agent-project>, <your-personal-ai-project>). Buttons over free-text, no gating on user, act on implied consent, trust character over rules.
type: learned-pattern
applies-to: [content, build, delegation]
projects: [all]
severity: warning
phase: [build, content, review]
trigger: [telegram-bot-design, persona-tuning, bot-ui-decision]
last-validated: 2026-05-18
archetypes: [telegram-bot]
---

# Pattern: Bot Conversational UX

Synthesized from 14+ feedback files across <your-personal-ai-project>, <your-agent-project>/<your-agent-project>, and <your-bot-1>. Same patterns surfaced independently in each bot — promote to global.

## Default to inline-keyboard buttons over free-text

When the bot needs a discrete choice from the user, default to Telegram inline keyboards (`reply_markup.inline_keyboard`). Free-text replies for choices cause: typos, ambiguous parses, longer roundtrips, drift into unrelated conversation. Use free-text only when the user genuinely needs to author content.

Rule: if there are ≤6 valid next moves, render them as buttons. (<your-bot>/feedback_ask_choice_buttons_whenever_possible.md)

## Don't gate on the user — act on implied consent

When user intent is clear from context, ACT — don't ask "are you sure?" or "want me to proceed?" Gating on confirmation reads as condescension to a senior user who already typed their intent. The bot should default to action with a brief "doing X" stamp, and recover gracefully if wrong.

Counter-example: <your-agent-project> waited for explicit "yes proceed" after you said "ship the PR" → got told to stop gating. (<your-agent-project> + <your-bot>/feedback_dont_gate_on_me.md)

## No empty validation-fishing questions

Banned phrases: "does that resonate?", "make sense?", "want me to keep going?" These are validation-fishing, not real questions. They cost a roundtrip and signal lack of confidence.

OK phrases: pseudo-greeting openers like "good question" or "OK, here's the thing" — these warm the response without asking the user to validate. (<your-bot>/feedback_no_empty_questions_be_curious.md)

## Trust character over rules

Encoding bot behavior via long "don't do X, don't do Y" rule lists fails — the LLM defaults to the rule's negation when the rule isn't loaded. Instead, encode behavior via positive shapes + examples. "When uncertain, ask one specific question and propose the most likely next move" beats "don't gate, don't be vague, don't ask multi-part questions."

For high-stakes behavior (send_email, transfer_money, delete), encode via mandatory tool params (e.g., `confirm: bool` that defaults to None). For low-stakes voice rules, use prose in the system prompt. Don't conflate the two. (<your-bot>/feedback_trust_character_over_rules.md, feedback_voice_rule_vs_mandatory_params.md)

## Long pasted text = context import, not escape

When a user pastes a long block of text (meeting notes, transcript, doc), treat it as rich context import — not as a signal they want to "escape" the current flow. Quote-acknowledge the input ("got it, parsing this for X"), then continue the existing thread informed by the new context. (<your-bot-1>/feedback_bulk_paste_is_context_import.md)

## Pseudo-greetings are OK; warmth ≠ harshness vs softness

Persona warmth calibrates on the wrong axis when framed as "harsh vs soft." Real axis: "specific vs generic." A specific firm answer ("you're stuck because X — do Y") reads as caring; a vague soft answer ("that sounds tough") reads as fake. Firm ≠ harsh. (<your-bot-1>/feedback_firm_does_not_mean_harsh.md, feedback_persona_warmth_calibration.md)

## Offerings, not actions, in bot menus

When a bot exposes a menu of what it can do, frame items as offerings ("Help me ship today's task", "Audit my project") not raw actions ("call_tool: ship_audit"). Offerings are user-language; actions are implementation-language. (<your-bot-1>/feedback_offerings_not_actions.md)

## OAuth-via-Telegram uses public callback, NOT localhost

When a Telegram bot triggers an OAuth flow (Google, GitHub), the callback URL must be the bot's public Railway/Vercel URL — NOT localhost. The user clicks the auth link in Telegram on their phone; localhost is meaningless. Register the public callback in the OAuth client and route `/oauth/callback` to the bot's user-context resolver. (<your-agent-project>/feedback_oauth_via_telegram_uses_public_callback_not_localhost.md)

## Cross-refs
- `delegation-discipline.md` — agent routing rules
- `voice-and-content-rules.md` — nurture voice (no timing-shame applies to bot replies too)
- Project memory: `<your-bot>/feedback_*`, `<your-agent-project>/feedback_*`, `<your-bot-1>/feedback_*`
