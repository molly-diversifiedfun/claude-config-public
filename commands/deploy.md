Deploy the current project.

Usage: /deploy [environment]

## Pre-flight (NEW Phase 3)

Before deploying:
1. `mcp__mempalace__mempalace_search` for "deploy <project>" + "<deploy-target> gotchas" (e.g., "vercel env var", "railway port binding")
2. Wing filter by project — fail open per `feedback_mempalace_wing_filter_error_finding_id.md`
3. Pull: past deploy failures + their fixes, 3-deploy-rule incidents, observability gotchas, env var checklists
4. ESPECIALLY check `learned/deploy-iteration-discipline` and any `feedback_*` capturing this project's deploy quirks

This will:
1. Run type checking (`npx tsc --noEmit`)
2. Run tests (`npm test` or `bun test`)
3. Run linting (`npx biome check .`)
4. Build for production (`npm run build`)
5. If all checks pass, deploy to the specified environment:
   - `vercel` → `npx vercel --prod`
   - `staging` → `npx vercel` (preview deploy)
   - Default: staging

Deployment will be blocked if any checks fail.
