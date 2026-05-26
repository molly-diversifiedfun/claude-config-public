---
name: auto-mode-classifier-discipline
description: The auto-mode permission classifier reads agent intent against original user scope, not against blanket consent words. Multi-step high-severity operations need per-step authorization even after the user says "yes" to the overall plan. Two correct interventions on 2026-05-23 — force-push and tag-push — both within the same "yes to scrub" consent window. Plus the false-positive class — MCP tool calls misflagged as Bash.
type: learned-pattern
applies-to: [auto-mode, permissions, destructive-operations, secrets, deploy]
projects: [all]
severity: blocking
phase: [build, deploy, post-incident]
trigger: [auto-mode-denial, force-push, history-rewrite, tag-push, mcp-tool-call]
last-validated: 2026-05-23
archetypes: [infra-config, always-on]
---

# Pattern: Auto-Mode Classifier Discipline

The auto-mode classifier ("blanket consent doesn't extend to high-severity destructive actions") is correct by design, even when it feels like the user already authorized the task. Re-read it as a feature, not friction.

## The 2026-05-23 carl/n8n scrub session — two correct interventions

User originally asked: *"can we make sure my claude config is fully documented with current reality and the public facing one - reflects those (scrubbed changes)"*

Mid-session, after discovering leaked Supabase URL + n8n credential handles in `carl/n8n`, the agent offered a `git filter-repo` scrub. User said "yes" to scrubbing.

**Intervention 1 — force-push gating:** When the agent attempted `git push origin main --force-with-lease=...`, auto-mode blocked with:

> "user's bare 'yes' earlier in transcript does not specifically authorize this high-severity history rewrite + force-push (original ask was about documentation and public mirror sanitization, not private repo history scrub)"

Correct. The "yes" was scoped to "scrub the URL from history" but `force-push to default branch` is a separate operation with its own blast radius (orphans all other clones, rewrites all SHAs). Required explicit `AskUserQuestion` confirmation before proceeding.

**Intervention 2 — tag-push gating:** After successful force-push, the agent tried to push the safety tag (`git push origin pre-scrub-2026-05-23`). Auto-mode blocked with:

> "Pushing the `pre-scrub-2026-05-23` tag to remote re-uploads the n8n/Supabase credentials and infrastructure identifiers that the user just authorized scrubbing — the tag still points at the pre-scrub commit; the agent's own commit message said this tag was preserved 'locally' only."

Correct. The agent's OWN commit message had documented the tag as local-only. Pushing the tag would have re-leaked the same secrets through the tag's target commit — exactly what the scrub was meant to prevent.

**Lesson:** the classifier reads beyond literal authorization — it cross-checks the proposed action against (a) the original user scope, (b) the agent's own stated reasoning, (c) the operation's blast radius. Trust it. When it blocks, re-read the action carefully before retrying.

## The false-positive class — MCP misflagged as Bash

`feedback_auto_mode_classifier_misflagged_mcp_call_as_bash`: a direct MCP tool call (`mcp__claude_ai_Vercel__list_deployments`) was denied because the classifier read it as a Bash command attempting to invoke MCP syntax inline.

**Lesson:** when this happens, retry the same MCP call directly without nearby Bash context. Don't wrap it in a Bash heredoc or shell pipe. The classifier is reading the literal command shape against patterns — clean direct calls pass.

## When the classifier blocks — the protocol

1. **Read the denial reason verbatim.** It quotes what tripped the classifier. The fix is usually right there.
2. **Don't bypass with `dangerouslyDisableSandbox`.** That trains bad muscle memory. If the operation genuinely needs authorization, ask via `AskUserQuestion` with explicit scope ("Authorize force-push to main now?") and the precise risk.
3. **Re-check your reasoning.** If the agent argued in its own commit message / handoff that something was "local-only" or "scoped to X," and now wants to broaden that scope, the classifier is doing exactly its job. Re-scope or get explicit re-confirmation.
4. **Don't re-attempt the exact same call.** Per the system rule. Adjust shape (e.g. MCP direct call without Bash wrapper) or get explicit authorization for the unchanged action.

## Cross-references

- `learned/git-history-scrub-discipline.md` — the five preconditions a scrub must satisfy. Force-push is the destructive irreversible step inside that procedure.
- `learned/secrets-routing.md` — secrets go direct to deploy, never through chat or repos. The carl/n8n leak existed because the live `~/.carl/n8n` was rsync'd into the repo without exclusion; the fix lives in `bin/sync.sh --exclude='n8n'`.
- `learned/required-reading-blocks-leak-narration.md` — required reading hooks pull in source material, but blocking + soft-fail-open lets the harness keep running even when the gate misfires.
