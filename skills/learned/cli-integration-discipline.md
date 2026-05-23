---
name: cli-integration-discipline
description: Before designing pipeline caps + parser logic around any external CLI (claude -p, gh, railway, etc.), run ONE real call with realistic input to measure cost, latency, and output shape. The default invocation is rarely the cost-optimized one. For `claude -p` specifically, `--bare` is the only acceptable production flag — default loads ~105k tokens of context every call.
type: learned-pattern
applies-to: [llm-integration, cli-wrappers, subprocess, cost-discipline, spec-design]
projects: [all]
severity: blocking
phase: [brainstorm, spec, build]
trigger: [claude-cli, llm-judge, llm-synthesis, subprocess-wrapper, cli-pipeline]
last-validated: 2026-05-23
archetypes: [infra-config, telegram-bot, content-pipeline]
---

# Pattern: CLI Integration Discipline

When wrapping an external CLI (especially LLM CLIs like `claude -p`, but also `gh`, `railway`, `firecrawl`, etc.) in a pipeline, the spec MUST include a pre-build smoke step: run ONE real call with realistic input, measure cost + latency + output shape, and only then design pipeline caps + parser logic.

Without this step, the spec calibrates against assumed behavior and ships against measured behavior — and they're rarely the same.

## The two failure modes

### 1. Cost was off by orders of magnitude

**Phase 7.7a.2 evidence (2026-05-22):** the LLM-judge pipeline was designed against an assumed Haiku cost of ~$0.006/call. The first live dogfood revealed default `claude -p --model claude-haiku-4-5-20251001` costs $0.13/call — 22× higher — because the default invocation loads ~105k tokens of CLAUDE.md/skills/hooks context EVERY call. The `--bare` flag skips this entirely.

4 commits (`a5d7fe5..11f14c3`) shipped with the broken invocation before the live-fix commit (`33ce83d`) added `--bare`. The cost surface only became visible at dogfood time. A 30-second pre-design smoke would have caught it.

### 2. Output shape was wrong

Same dogfood revealed two more issues:

- `--output-format json` returns an **envelope**, not raw model JSON: `{"type":"result","subtype":"success","result":"<actual response>","cost":...,"usage":{...}}`. The parser must extract the `result` field, not parse stdout directly.
- Even with `--json-schema` constraining the response, Haiku **wraps the response in markdown fences** (` ```json ... ``` `). The parser must strip fences before re-parsing.

Both detectable from a single real call. Both required a parser rewrite in the live-fix commit.

## Critical `claude -p` invocation pattern

For ANY future `claude -p` integration in a pipeline:

```bash
claude --bare -p \
  --model <model-name> \
  --output-format text \
  --no-session-persistence \
  --system-prompt "<role + output requirements>" \
  "<prompt>"
```

Critical flags + why:

| Flag | Why |
|---|---|
| `--bare` | **Mandatory.** Skips CLAUDE.md auto-discovery, plugin sync, hooks, auto-memory, keychain reads, background prefetches. Drops cost from $0.13 to $0.006/call (22×) AND latency from 28s to 9s (3×). |
| `-p` / `--print` | Non-interactive mode. Required for piped/scripted usage. |
| `--model` | Pick explicitly. Haiku 4.5 for cheap classification/judgment; Sonnet 4.6 for creative synthesis; Opus 4.7 for deep reasoning. |
| `--output-format` | `text` for raw model output (markdown, prose, etc.). `json` returns an envelope `{"type":"result","result":"<inner>","cost":...}` — use only if you need cost/usage metadata, and remember the parser needs to extract `result`. |
| `--no-session-persistence` | Don't save session to disk. Saves time + leaks fewer artifacts. |
| `--system-prompt` | Override the default system prompt entirely. Combined with `--bare`, this is the only system context the model sees. |

Optional flags worth knowing:

| Flag | Use case |
|---|---|
| `--json-schema "<json-string>"` | Structured-output validation. **Caveat:** does NOT suppress markdown-fence wrapping. Parser still needs to strip fences. |
| `--append-system-prompt` | Adds to the default system prompt instead of replacing. Use when you want minimal customization on top of Claude Code's defaults. Combines weirdly with `--bare` (which has no default system prompt). |
| `--max-budget-usd` | Hard cost cap per call. Defensive — combine with per-call timeout for runaway protection. |
| `--disable-slash-commands` | Skip skill resolution if the prompt accidentally mentions a skill. |

## Output envelope (when using `--output-format json`)

The envelope shape:

```json
{
  "type": "result",
  "subtype": "success",
  "result": "<actual model response as a string>",
  "is_error": false,
  "cost": 0.005852,
  "duration_ms": 9180,
  "ttft_ms": 9143,
  "usage": { "input_tokens": 1850, "output_tokens": 681, ... },
  "session_id": "...",
  "num_turns": 1
}
```

The `result` field contains the model's actual response as a string — which may itself be JSON, markdown, or wrapped in fences depending on the prompt + model.

**Parser pattern:**

```python
def parse_envelope_or_raw(stdout: str) -> dict | None:
    """Handle both --output-format json envelope AND raw text output."""
    text = stdout.strip()
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(parsed, dict):
        return None
    # Detect envelope shape: has 'result' field AND lacks expected response keys
    if "result" in parsed and isinstance(parsed["result"], str) and "<expected-response-key>" not in parsed:
        inner = _strip_fences(parsed["result"])
        try:
            return json.loads(inner)
        except json.JSONDecodeError:
            return None
    return parsed  # Raw shape (e.g., test mocks)
```

The dual-mode parser is robust against both production (real `claude -p`) and tests (bash mocks that echo raw JSON). The envelope-detection key: `"result" in parsed AND "<your-expected-response-key>" not in parsed`.

## The generalizable rule

Before designing pipeline caps, parser shape, or budget for ANY external CLI wrapper:

1. **Run ONE real call.** Time it. Note the cost. Inspect the output shape with `| head -50` AND `| python3 -m json.tool` (or equivalent for the format).

2. **Identify the cost-optimized invocation.** For `claude -p` this is `--bare`. For other CLIs, look for `--minimal`, `--no-startup-file`, `--quiet`, or equivalent. The default rarely is.

3. **Identify the output envelope.** If the CLI wraps responses in metadata (Claude does, `gh` does for some commands, `aws` does, etc.), the parser must extract the actual response field, not parse stdout directly.

4. **Identify model-specific quirks.** Haiku wraps JSON in markdown fences. Sonnet sometimes adds prose around structured output. Opus rarely drifts but is expensive. Match the parser to observed behavior, not hypothesized behavior.

5. **Document the smoke in the spec.** Add a "pre-build smoke" section with the exact command, observed cost, observed latency, observed output shape. Future changes reference this baseline.

## Pre-build smoke template (add to specs)

```markdown
## Pre-build CLI smoke

**Command:**
\`\`\`bash
claude --bare -p --model claude-haiku-4-5-20251001 --output-format text \
  "what is 2+2?"
\`\`\`

**Observed (date):**
- Cost: $0.006
- Wall time: 9.2s
- ttft: ~8s
- Output: raw text "4" (no envelope when --output-format text)

**Pipeline caps calibrated from this:**
- Per-call timeout: 30s (3x p50, covers ttft variance)
- Parallel workers: 8 (cost is low; concurrency is fine)
- Total budget: $0.006 × 500 pairs = $3 worst case
```

This template gets COPIED into the spec at brainstorm time, with real numbers from the smoke. If the smoke isn't run, the spec is incomplete.

## How to apply

**When writing a spec that wraps a CLI:**

- Add the pre-build smoke section.
- Run the smoke. Paste the actual output (or a representative excerpt).
- Calibrate caps/budgets/timeouts from the measured numbers.
- DON'T proceed to pipeline design without the smoke results in hand.

**When reviewing a spec:**

- Search the spec for "smoke" or "real call" or "measured." If absent, flag it.
- If the spec specifies per-call cost or latency without citing a measurement, demand the measurement before approving.

**When debugging mid-cycle live-fix issues like Phase 7.7a.2's:**

- Add the smoke retroactively to the spec.
- Update the relevant `feedback_*.md` with the discovered behavior.
- Re-cost the rest of the project based on real numbers.

## Why this matters

LLM CLI behavior is famously NOT what the docs say. The model wraps things in fences. The flag interactions are subtle. The default cost is suboptimal. The output format has hidden envelope shapes. The latency p95 is way wider than p50. None of these are visible from reading docs or examples — they only surface from running the real thing.

The cost of the smoke is 30 seconds. The cost of skipping it is a mid-cycle live-fix commit (Phase 7.7a.2: ~3 hours of subagent dispatch + review + integration that all had to be partially redone). The math is obvious.

## Related patterns

- `llm-judge-needs-retry-and-defensive-parse.md` — the safety net once a CLI is integrated; complementary to this pre-build discipline.
- `audit-trail-before-speculative-fix.md` — same root principle on debugging: measure before fixing.
- `never-fabricate.md` — applies during the smoke too: report observed cost/latency, not hypothesized.
- `dogfood-by-using-the-system-to-document-itself.md` — once the CLI integration ships, dogfood it; the smoke is the pre-build version of this same discipline.

Sourced from `feedback_phase_7_7a_2_llm_judge_dogfood_outcome.md` (the `--bare` discovery + envelope+fence parsing) and `feedback_session_2026_05_22_dogfood_driven_iteration_learnings.md` (the generalizable rule). Two-data-point synthesis from the same session — the second data point made the first generalizable instead of a one-off "Claude Code quirk."

## Claude Code transcript slug lossiness — never reverse-parse

Claude Code stores session transcripts at `~/.claude/projects/<slug>/<session-id>.jsonl` where `<slug>` is the cwd path with BOTH `/` AND `.` encoded as `-`. This makes reverse-parsing fundamentally lossy: `user.name` and `user-name` are indistinguishable after encoding (both become `user-name`), so `$HOME/github/<your-bot>` → `<your-workspace>-<your-bot>` could plausibly reverse to a non-existent `/Users/user-name/github/<your-bot>` path.

**The rule:** when you need to map slugs back to real paths (for cross-session analysis, `git log` joins, archetype detection, etc.), build a FORWARD index — walk likely cwd roots (`~`, `~/github`, `~/Desktop`, `~/Downloads`, `~/.claude`, `/private/tmp`, `/tmp`) two-deep, compute each real dir's slug, build `dict[slug, str(real_path)]`. Cache the index per analyzer run.

**Why this matters:** `/system-retro` (Phase 7.7c, 2026-05-23) initially used a reverse-parser that produced phantom paths like `/Users/user-name/github/...` that didn't exist on disk. Every `git log` join failed silently — the "commits this session shipped" column was empty across every row. Symptom looked like "we don't track commits during sessions"; root cause was lossy slug encoding.

**Test pattern:** for any new analyzer that consumes transcript slugs, add a unit test that round-trips a real cwd → slug → resolved path → confirms exists. Regression test pattern at `~/.claude/test/system-retro/08-cwd-slug-roundtrip.sh`.

**General principle:** any encoding scheme that maps two characters to one is lossy. The presence of slugs in a directory listing is NOT the absence of ambiguity; it's a hidden information-loss boundary. Treat slugs as opaque IDs you JOIN against a forward-built table, not as parseable paths.

Sourced from `feedback_transcript_slug_encoding_is_lossy.md`.
