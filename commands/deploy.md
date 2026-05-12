Deploy the current project.

Usage: /deploy [environment]

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
