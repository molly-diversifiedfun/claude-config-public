# Project CLAUDE.md Template

Use this as a starting point for any new project's `.claude/CLAUDE.md`.

## Project Overview
- **Name**: [project name]
- **Stack**: TypeScript, Vite, Supabase, Tailwind CSS
- **Purpose**: [one-line description]

## Architecture
- `src/` — application source code
- `src/components/` — reusable UI components
- `src/lib/` — shared utilities and API clients
- `src/hooks/` — custom React/Preact hooks
- `supabase/` — database migrations and edge functions

## Conventions
- Follow global rules in `~/.claude/CLAUDE.md`
- Use existing component patterns before creating new ones
- All API calls go through `src/lib/`
- Feature branches: `feat/[description]`, bug fixes: `fix/[description]`

## Key Files
- `TASKS.md` — current task list (auto-managed)
- `HANDOFF.md` — session continuity state (auto-managed by hooks)
- `README.md` — project documentation

## Testing
- Run tests: `npm test` or `bun test`
- Run type check: `npx tsc --noEmit`
- Run lint: `npx biome check .`
