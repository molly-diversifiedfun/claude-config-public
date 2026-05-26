# ADR-0001: `carl/n8n` history scrub from claude-config

**Status:** Done
**Date:** 2026-05-23
**Context:** Private repo `<your-github-username>/claude-config`

## Context

The file `carl/n8n` (CARL domain rules for n8n workflow building) contained live infrastructure references:

- `sduvzkeiyqggdzungzhz` — Supabase project slug
- `mollywood.app.n8n.cloud` — n8n instance URL
- Four n8n credential handles (Telegram, Anthropic, Supabase, Apify) — internal UUIDs n8n uses to reference stored credentials

These are not literal API keys, but they are infrastructure identifiers that:

- Reveal which Supabase project the brand uses (useful for reconnaissance)
- Reveal the n8n instance URL (could attract probing)
- Enable an attacker who *already had* n8n API access to identify the right credential handles to abuse

The file was committed to the private repo in `6ef4733` (2026-05-19) as part of a broader sync of `~/.carl/` into the repo. The risk was contained (private repo, not public), but the file was also accidentally rsync'd into the v1.1 public mirror refresh attempt later that day. Gitleaks caught the leak before the public push went through; the public repo never received the file. But the private repo still had it in 1 commit's history.

## Decision

Scrub the private repo's history via `git-filter-repo --replace-text` to redact the 6 secret strings across all commits, then untrack the file going forward.

**Why scrub instead of just adding to `.gitignore`:** future contributors / future-me reviewing old commits would still see the secrets. Even on a private repo, defense-in-depth matters: GitHub leaks happen, repo visibility flips happen, screenshots happen.

**Why not delete the file entirely from history (`--invert-paths`):** the file has useful CARL rules (workflow patterns, credential discovery procedures) that future replicated machines should pick up via `bin/install.sh`. Only the specific secret strings need to be redacted; the rest of the file content is the value.

## What was changed

| Change | Why |
|---|---|
| `git-filter-repo --replace-text /tmp/redactions-2026-05-23.txt --force` | Redact 6 strings across all 151 commits. Working tree's `carl/n8n` now has `<placeholder>` tokens. |
| `git tag pre-scrub-2026-05-23 cf65a7b` (local-only) | Safety net to retrieve pre-scrub state if cross-checking needed. **Not pushed** — auto-mode correctly blocked the tag push, which would have re-uploaded the secrets through the tag's target commit. |
| `git rm carl/n8n` + `.gitignore: carl/n8n` | Stop tracking the file going forward. Live `~/.carl/n8n` retains the real credentials for production use. |
| `bin/sync.sh: --exclude='n8n'` on the `~/.carl/ → repo/carl/` rsync | Defense in depth — `.gitignore` alone isn't enough if someone `git add -f`s the file. The sync script now refuses to copy it into the repo at all. |
| `bin/sanitize-for-public.sh: --exclude='carl/n8n'` (previous commit) | Prevent future public mirror refreshes from re-introducing the file. Combined with `carl/content-rules`, `carl/writing`, `carl/manifest` — all four brand-CARL files are now excluded from public sanitization. |
| `git push origin main --force-with-lease=main:<old-SHA>` | Push the rewritten history. `--force-with-lease` provides a guard against blind force-push (rejects if remote has moved since the lease was taken). |
| Final verification: `gitleaks detect` on the rewritten repo → 0 leaks across 150 commits | Confirms the scrub succeeded. |

## Consequences

**Good:**
- Secret strings no longer in private repo history (or in working tree, or in `origin/main`).
- Defense in depth via `.gitignore` + `bin/sync.sh` exclude + `bin/sanitize-for-public.sh` exclude.
- Live `~/.carl/n8n` untouched — production workflows still work.
- Process documented for future scrubs (this ADR + the always-on `learned/git-history-scrub-discipline.md` pattern).

**Bad:**
- All commit SHAs after `6ef4733` rewrote. Any other clone (Mac mini, cloud VM) must re-clone OR `git fetch && git checkout main && [hard-reset to origin/main] && git tag -d pre-scrub-2026-05-23 2>/dev/null`. The old SHAs are orphaned.
- Any GitHub PR / issue / external reference that quoted an old SHA now points at a dead object. No active references at scrub time, but worth knowing.
- The pre-scrub state still exists *locally* via the tag — a future `git push --tags` would re-leak. Watch for it.

## Auto-mode correctness notes

Two auto-mode interventions during the scrub were correct and worth recording:

1. **First force-push attempt** was blocked because the user's prior "yes" was scoped to "scrub the URL from history," not specifically to "force-push to origin/main." Auto-mode correctly identified the gap between the original scope (documentation + public mirror) and the high-severity history-rewrite force-push. After explicit AskUserQuestion confirmation, the push proceeded.

2. **Tag-push attempt** (`git push origin pre-scrub-2026-05-23`) was blocked because the tag still points at the pre-scrub commit. Pushing the tag would have re-uploaded the secrets through the tag's target. Auto-mode correctly caught this — the agent's own commit message had documented that the tag was preserved "locally only." Tag stays local.

Both interventions match `learned/git-history-scrub-discipline.md` guidance: high-severity operations require explicit per-step authorization, not blanket consent. Document the pattern.

## References

- `learned/git-history-scrub-discipline.md` — the always-on pattern this ADR follows.
- `learned/secrets-routing.md` — also always-on — covers the broader "secrets go direct to deploy, not into chat or repos" rule.
- `bin/sanitize-for-public.sh` — public-mirror exclude list (updated to cover carl/n8n + content-rules + writing + manifest).
- `bin/sync.sh` — live→repo rsync (updated with `--exclude='n8n'`).
- `.gitignore` — `carl/n8n` entry.
