# settings.example.json — wire-in guide

`~/.claude/settings.json` is **gitignored** in this repo (it contains personal paths, MCP server URLs, and other host-specific bits). `settings.example.json` is a sanitized snapshot you can use as a starting point for a fresh install or a new machine.

## What's sanitized

| In the live file | In the example |
|---|---|
| `$HOME/.claude/...` paths | `~/.claude/...` |
| `deniedMcpServers` (specific service names) | `<example_denied_mcp_server_*>` placeholders |
| `extraKnownMarketplaces.*.source.repo` | `<owner>/<repo>` |
| Personal cache paths under `/Users/...` | Removed |
| Plugin marketplaces with personal/cache directory sources | Removed |

Everything else (permissions allow/deny lists, hook command structure, env vars, statusLine, enabled plugins) mirrors the live shape.

## Steps to use on a fresh install

### 1. Copy to the live location

```bash
cp ~/github/claude-config/settings.example.json ~/.claude/settings.json
```

### 2. Replace the `~/` paths

`jq`/`sed` substitute `~/.claude/` with `$HOME/.claude/`:

```bash
sed -i.bak "s|~/.claude/|$HOME/.claude/|g" ~/.claude/settings.json
rm ~/.claude/settings.json.bak
jq . ~/.claude/settings.json > /dev/null && echo "valid"
```

(The harness expects absolute paths in hook `command` fields.)

### 3. Make sure the hook scripts exist

Run `bash ~/github/claude-config/bin/sync.sh` (or copy `hooks/` into `~/.claude/hooks/` and `chmod +x` each script). Required scripts referenced by this settings file:

- `session-restore.sh`, `session-end-save.sh`, `session-retrospective.sh`
- `synthesize-learnings.sh`, `check-model-freshness.sh`
- `carl-loader.sh`
- `observe-learning.sh`
- `block-dangerous.sh`, `pre-commit-checks.sh`, `block-issue-close-without-tests.sh`, `caption-guard.sh`
- `caption-pipeline-guard.sh`, **`audience-gate.sh`** (audience-gate enforcement)
- `pre-compact-save.sh`
- `workflow-gate.sh`, **`agent-batch-validator.sh`** (file-count + scope-fidelity)
- `prettier-format.sh`, `content-qa-guarded.sh`, `validate-n8n-workflow.sh`
- `auto-push-after-commit.sh`
- `ship-phase-gate.sh`
- `auto-approve.sh`
- `gsd-statusline.js` (Node statusline)

### 4. Re-add your own MCP denials

`deniedMcpServers` is example-stubbed — add the MCP servers you want to deny in your environment. To list which servers your Claude has connected, check the MCP UI in Claude Code.

### 5. Re-add personal marketplaces

`extraKnownMarketplaces` should hold the plugin marketplaces you authorize. The example has one stub. Add your own (GitHub repo or local directory source).

### 6. (Optional) Add audience-gate state directories

The audience-gate hook writes session state under `~/.claude/state/` and logs under `~/.claude/logs/`. They're created on first fire, but you can pre-create them:

```bash
mkdir -p ~/.claude/state ~/.claude/logs ~/.claude/checkpoints
```

## Audience-gate wire-in (the bit that lives in settings.json)

The audience-gate hook is registered under `PreToolUse` with matcher `Write|Edit`. The relevant block in `settings.example.json`:

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {"type": "command", "command": "~/.claude/hooks/caption-pipeline-guard.sh", "statusMessage": "Checking caption pipeline..."},
    {"type": "command", "command": "~/.claude/hooks/audience-gate.sh", "statusMessage": "Checking audience for deliverable..."}
  ]
}
```

This is the live wire-in. If you copy `settings.example.json` -> `settings.json` (with path replacement per step 2), audience-gate is wired automatically. No further manual edit needed.

## Kill switches

If a gate fires too aggressively on your workflow, disable per-session via env var:

- `export AUDIENCE_GATE=off` — disable audience-gate (PreToolUse:Write|Edit)
- `export SCOPE_GATE=off` — disable scope-fidelity check in agent-batch-validator (PreToolUse:Agent)
- `export ARCHETYPE_GATE=off` — disable archetype-injector (UserPromptSubmit, Phase 6.2)

These bypass the gate without removing the wire-in. To re-enable: unset the env var or open a fresh shell.

## Phase 6.2 — archetype-injector.sh wire-in

`archetype-injector.sh` is a UserPromptSubmit hook that detects the active project archetype from `cwd` (via `~/.claude/projects.yaml`), then emits an `additionalContext` block listing only the `~/.claude/skills/learned/` patterns relevant to that archetype, plus all `severity: blocking` patterns. Caches per-cwd in `~/.claude/checkpoints/archetype-cache.json` keyed on manifest+learned mtime.

To wire it in alongside the existing carl-loader entry, run (back up first):

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '.hooks.UserPromptSubmit += [{"hooks":[{"type":"command","command":"/Users/<you>/.claude/hooks/archetype-injector.sh"}]}]' \
  ~/.claude/settings.json > ~/.claude/settings.json.new && mv ~/.claude/settings.json.new ~/.claude/settings.json
jq . ~/.claude/settings.json > /dev/null && echo valid
```

Spec/plan: `~/github/docs/superpowers/{specs,plans}/2026-05-20-phase-6-2-archetype-injection*.md`.

## Phase 7.6 — agent-eval.sh LLM-judge wire-in (2026-05-21)

`agent-eval.sh` is the Phase 7.6 post-dispatch LLM-judge. It runs in two modes via a single script:

- `--enqueue` (PostToolUse:Agent) — snapshots dispatches with Phase 7.5.1 markers to `~/.claude/data/agent-eval-queue/<ts>-<uuid>.json`. Soft-fails open. Kill: `AGENT_EVAL=off`.
- `--drain` (Stop hook, **after `session-retrospective.sh`** so the DoD gate fires first) — invokes `claude -p --model claude-haiku-4-5-20251001` per snapshot, validates with jq retry-once, appends judgments to `~/.claude/data/agent-eval.jsonl`. Caps: 20 files / 300s per drain, 30s per eval. Kill: `AGENT_EVAL_DRAIN=off` (collect snapshots without spending tokens) or `AGENT_EVAL=off` (full off).

To wire it in on a fresh install:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '
  .hooks.PostToolUse += [{
    "matcher": "Agent",
    "hooks": [{
      "type": "command",
      "command": "~/.claude/hooks/agent-eval.sh --enqueue"
    }]
  }]
  | .hooks.Stop[0].hooks += [{
      "type": "command",
      "command": "~/.claude/hooks/agent-eval.sh --drain",
      "statusMessage": "Draining agent-eval queue..."
    }]
' ~/.claude/settings.json > ~/.claude/settings.json.new && mv ~/.claude/settings.json.new ~/.claude/settings.json
sed -i.bak "s|~/.claude/|$HOME/.claude/|g" ~/.claude/settings.json && rm ~/.claude/settings.json.bak
jq . ~/.claude/settings.json > /dev/null && echo valid
```

Add `AGENT_EVAL=off` / `AGENT_EVAL_DRAIN=off` to the kill switches list above when you ship this on a new machine.

The Phase 7.5 wire-in (PreToolUse:Agent → `hooks/inject-skills-for-agent.sh`) is independent and must exist for Phase 7.6 to have anything to evaluate.

Spec/plan: `~/github/docs/superpowers/{specs,plans}/2026-05-21-phase-7-6-llm-judge-evaluator*.md`.

## Reference

- Spec: `~/github/docs/superpowers/specs/2026-05-15-claude-setup-enforcement-gates-design.md`
- Plan: `~/github/docs/superpowers/plans/2026-05-15-claude-setup-enforcement-gates.md`
- Source hooks: `hooks/audience-gate.sh`, `hooks/agent-batch-validator.sh`, `hooks/carl-loader.sh`, `hooks/inject-skills-for-agent.sh` (Phase 7.5), `hooks/agent-eval.sh` (Phase 7.6) (in this repo)
