Create a new project with proper Claude Code configuration.

Usage: /init-project

This will:
1. Create `.claude/` directory in the current project if it doesn't exist
2. Generate a project-specific `CLAUDE.md` from the template at `~/.claude/commands/new-project-template.md`
3. Create empty `TASKS.md` and `HANDOFF.md` files
4. Set up `.claude/settings.local.json` with project-specific permissions

Customize the generated `CLAUDE.md` with your project's specific stack, architecture, and conventions.
