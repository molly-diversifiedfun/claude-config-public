---
name: domain-repo-analytics-mapping
description: BLOCKING. Verify domain↔repo↔analytics mapping via Vercel `domains` field before wiring anything. Brand name ≠ repo name ≠ Vercel project name ≠ production domain.
type: learned-pattern
applies-to: [deploy, infra, observability, secrets]
projects: [all]
severity: warning
phase: [pre-flight, deploy]
trigger: [analytics-wiring, env-var-add, deploy-hook, attribution-debug, vercel-migration]
last-validated: 2026-05-20
archetypes: [web-app]
---

# Pattern: Domain ↔ Repo ↔ Analytics Mapping

Brand name ≠ repo name ≠ Vercel project name ≠ production domain. Always verify the mapping before wiring analytics, env vars, deploy hooks, or attribution.

## The verification step (BLOCKING)

Before adding any PostHog snippet, env var, redirect, or analytics tag to a web app:

```bash
vercel projects ls
vercel project inspect <project-name>  # check the `domains` field
```

The `domains` field is authoritative. If `theshipitsystem.com` is on project `ship-it-ally` (not `theshipitsystem`), wire analytics to `ship-it-ally`. Brand names lie about which repo does what.

The 2026-05-16 ship-it-ally / theshipitsystem incident cost ~5 commits to untangle because I assumed instead of verified. (workspace/feedback_verify_domain_repo_mapping.md)

## PostHog gotchas

- **person_profiles: "identified_only" ordering.** Call `posthog.capture()` BEFORE `posthog.people.set_once()`, AND wrap `set_once` in try/catch. `set_once` silently fails on anonymous users and can kill the chain if not caught. (workspace/feedback_posthog_capture_order_and_lag.md)
- **Cloud query API lag is 5–10 min on new projects**, not 30s. Trust `{status: "Ok"}` from `/e/` endpoint + wait ≥10 min before declaring capture failure. Bot-filter / gzip / UA debugging are red herrings.
- **Three PostHog projects in one org.** 415939 = unstuckwithmolly.com, 417699 = justshipitapp.com, 426369 = theshipitsystem.com. Attribution insights live in the project that owns the destination domain — verify destination via `?ref=` URL targeting before configuring.

## SSG and Vercel quirks

- **Document-level click handler for ref-attribution.** Build-time URL decoration in a vite-react-ssg app is a no-op because static HTML is pre-rendered. Use a document-level click handler that intercepts navigation and appends `?ref=` query params at click time.
- **Apex → www 307 defeats Meta domain verification.** Meta's verification crawler doesn't follow 307 redirects to subdomains. Register `www` directly with Meta (or both apex + www), don't rely on apex-only with a www redirect.
- **Vercel rewrites with `statusCode: 302`** add ~500ms vs plain redirects. For canonical URL redirects, prefer `redirects` config over `rewrites` with status codes.

## Vercel CLI migration recipe (~10 min)

For moving a Vite app from Lovable/Netlify/other to Vercel:

```bash
vercel link --yes --project <NAME> --scope <TEAM>
vercel env add <VAR_NAME> production    # repeat per env var
vercel deploy --prod
vercel domains add <domain.com>
```

(workspace/reference_vercel_cli_migration_recipe.md)

## Secrets-handling gotchas during migration

- **`echo` adds a newline to `vercel env add`.** The stored value has a trailing `\n` and breaks API calls. Use `printf "%s"` instead. (workspace/feedback_session_2026_05_16_learnings.md)
- **Never paste secrets to chat.** Route directly to Vercel/Railway/1Password. See `secrets-routing.md`. (workspace/feedback_secrets_go_direct_to_deploy.md)

## Cross-refs
- `secrets-routing.md` — never paste secrets to chat
- `deploy-iteration-discipline.md` — 3-deploy rule, observability before iteration
- Workspace memory: `reference_posthog_setup.md`, `reference_vercel_cli_migration_recipe.md`
