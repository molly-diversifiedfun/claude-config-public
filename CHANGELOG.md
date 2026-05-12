# Changelog

All notable changes to this snapshot will be documented here. This is a one-shot snapshot of a working personal config — there is no commitment to future versions, but if one ships, it lands here.

Format roughly follows [Keep a Changelog](https://keepachangelog.com). Versioning is calendar-based (`vYYYY.MM.DD`), not semantic — this isn't a library, it's a configuration mirror.

---

## [v1.0] — 2026-05-12

### Initial public snapshot

- **36 skills** (`skills/`) — custom skills auto-invoked via the Skill tool. Includes 16 `learned/` cross-project patterns with v2 frontmatter for the memory-aware `/ship` pipeline.
- **14 agents** (`agents/`) — `product-lead`, `engineer`, `reviewer`, `designer`, `debugger`, `tech-researcher`, `security`, `project-manager`, `memory-keeper`, 4 `content-*` lanes, `market-researcher`.
- **21 hooks** (`hooks/`) — lifecycle scripts including `session-retrospective.sh` (Stop, 7-check DoD), `block-dangerous.sh` (PreToolUse:Bash, 11/11 test cases), `observe-learning.sh` (telemetry), `ship-phase-gate.sh` (gates `/ship` Stage 9).
- **18 slash commands** (`commands/`) — `/fix`, `/build`, `/ship`, `/write`, `/plan`, `/handoff`, `/escalate-to`, etc.
- **11 rule files** (`rules/`) — common conventions + CARL domain configs.
- **8 docs files** (`docs/`) — architecture, ship-pipeline-v2 spec, install guide, skills/agents/commands/hooks catalogs.
- **4 bin scripts** (`bin/`) — `install.sh`, `sync.sh`, `bootstrap.sh`, `sanitize-for-public.sh`.

### Sanitization
Generated from a private working config via `bin/sanitize-for-public.sh`. Zero personal handles, zero personal project names, zero hardcoded paths. `brand-voice-router/` shipped as a template stub. `rules/content-system/` excluded entirely.

### Visual artifacts
- 11-stage `/ship` pipeline Mermaid diagram (renders natively on GitHub).
- 1200×630 OG social card at `assets/og-card.png` — uploaded as the repo's social preview.

### Audience
Power users + Claude Code builders. Not beginners. Read `docs/architecture.md` and `docs/ship-pipeline-v2.md` before installing.

### Followability score (self-assessed, post-redesign)
UNDERSTAND 5 / BELIEVE 5 / DO 5 / REPEAT 3 / SHARE 4 — avg 4.4.

---

## Future versions

If v1.1 ships, expect:
- Updated counts as the private config drifts
- New `learned/` patterns from intervening sessions
- Hook tightening based on real failures

No timeline. Watch the repo or check back; either is fine.
