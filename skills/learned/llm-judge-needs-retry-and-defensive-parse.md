---
name: llm-judge-needs-retry-and-defensive-parse
description: "LLM-as-judge pipelines need BOTH a retry-with-stricter-prompt AND defensive shape-validation on the parsed JSON. A judge can return syntactically valid JSON with the wrong keys (missing `verdicts`) and silently bypass the retry — same failure mode the retry was meant to prevent. Distinguish None (retry) from [] (legit empty)."
type: learned-pattern
applies-to: [llm-as-judge, testing, eval-harness, content-qa, dispatch-routers, prompt-engineering, python]
projects: [all]
severity: warning
phase: [build, test, verification]
last-validated: 2026-05-23
archetypes: [telegram-bot, content-pipeline, always-on]
---

# LLM-Judge Pipelines: Retry + Defensive Parse, Both Required

**Origin:** 2026-05-19 Dana smoke `/ship` review (`.ship/2026-05-19-dana-rubric-and-fixes/review.md`, MEDIUM finding #1). A3 added retry-on-JSON-parse-failure to `tests/dana-smoke.py`. Reviewer caught that valid-JSON-with-wrong-keys still slipped through silently.

## The two failure modes (both real)

1. **JSON parse failure** — judge wraps output in ```json fences, or emits prose around the JSON, or truncates. `json.loads` throws.
   - Mitigation: `_strip_fences_and_parse()` strips fences, extracts first-`{` to last-`}`, retries with stricter system prompt.
   - Reference: `feedback_haiku_drift_strip_fences.md` (Haiku does this regularly; Sonnet sometimes; Opus rarely).

2. **JSON shape mismatch** — judge returns valid JSON with the wrong top-level key. Example: `{"results": [...]}` or `{"evaluations": [...]}` instead of `{"verdicts": [...]}`. `json.loads` succeeds. `parsed.get("verdicts", [])` returns `[]`. Caller sums 0✓ 0✗ silently. **The turn is counted as zero verdicts, not as a fail — invisible regression.**
   - Mitigation: helper MUST validate that `verdicts` is present AND is a non-empty list before returning. If absent or empty, return `None` so the retry path fires.

## The trap

You add retry-on-`JSONDecodeError` and feel safe. But the judge model can return well-formed JSON with the wrong schema — that's a different exception path (`KeyError` if you index, or silent default if you use `.get`). The retry never fires because nothing threw.

The model that does this is rare (Sonnet 4.6 with strict response_format almost never does), but stochastic — it happens. When it happens, the verdict is silently 0/0 instead of N/N. You can't see the bug from the test summary because "0 fails" looks identical to "all passed".

## What good looks like

```python
def _strip_fences_and_parse(raw: str) -> Optional[List[Dict]]:
    """
    Returns list of verdicts on success, or None if shape mismatch / parse error.
    NEVER returns [] for a parsing problem — empty list = legitimate "no verdicts in this turn".
    Caller distinguishes None (retry) from [] (legit empty).
    """
    cleaned = strip_code_fences(raw)
    cleaned = extract_brace_block(cleaned)
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        return None
    verdicts = parsed.get("verdicts")
    if verdicts is None or not isinstance(verdicts, list):
        return None  # shape mismatch; trigger retry
    return verdicts
```

```python
def judge_response(...) -> List[Dict]:
    verdicts = _strip_fences_and_parse(first_raw)
    if verdicts is None:
        # retry with stricter system prompt
        verdicts = _strip_fences_and_parse(second_raw)
    if verdicts is None:
        # both attempts failed → return FAIL fallback surfaced in `reason`
        return [{"criterion": "JUDGE_PARSE_ERROR", "pass": False,
                 "reason": f"both attempts unparsable: {first_raw[:200]} / {second_raw[:200]}"}]
    return verdicts
```

## The generalizable rule

For any LLM-as-judge pipeline (test runners, eval harnesses, content QA, dispatch routers):

1. **Always strip fences before parsing.** Haiku and Sonnet drift to fences under load.
2. **Always validate the parsed shape** — key present, type correct, list non-empty if expected non-empty.
3. **Distinguish `None` (parse/shape failure → retry) from `[]` (legit empty result).** Same return type = silent bug.
4. **Always surface JUDGE_PARSE_ERROR as a FAIL verdict, not as silent zero.** The test summary must visibly count it.
5. **Always log the raw response on parse/shape failure** so you can diagnose what the judge actually emitted.

## How to apply

- Audit any existing judge pipeline: grep for `.get("verdicts"` / `.get("results"` / similar default-to-empty patterns. Each one is a silent-failure surface.
- New judge pipelines: pattern the parse helper after the above structure.
- Add a unit test for shape mismatch specifically — pass in `{"results": [...]}` and assert the helper returns None, not `[]`.

Pairs with `feedback_haiku_drift_strip_fences.md` (the fence side) and `feedback_treat_root_cause_not_symptom.md` (observability over surface fix).

## Strict-JSON prompt calibration discipline

**The fence-and-retry machinery only protects against parse failures. It does NOT make the judge's strict-JSON output more likely to land cleanly on the first try.** Phase 7.6 smoke (2026-05-21) verified this empirically: both initial AND retry calls to `claude -p --model claude-haiku-4-5-20251001` failed strict-JSON validation despite a prompt that explicitly demanded "STRICT JSON only, no prose, no markdown fences." The failure-path machinery worked correctly (snapshot → `.failed/` → log) but the happy path never landed a row.

**Three calibration moves that improve first-call success rate:**

1. **Replace placeholder syntax with literal values in the schema spec.** A prompt that shows `{"used_injected_skill": <bool>, "quality_score": <int 1-5>}` invites the model to echo `<bool>` and `<int 1-5>` literally. Use concrete literals instead: `{"used_injected_skill": true|false, "quality_score": 1|2|3|4|5}`. Removes one ambiguity vector.

2. **Few-shot the schema with a complete example response.** A single concrete example (`Example: {"used_injected_skill": true, "which_skill": "humanize-ai-writing", "better_skill_suggested": null, "quality_score": 4, "rationale": "..."}`) gives the model a positive template to match. Negative-only instructions ("don't add prose") are weaker than positive-with-example.

3. **Try `--output-format json` instead of `text`** if the CLI supports it. Even when this wraps the response in a session-style envelope, the envelope is parseable as a known shape — far easier than parsing arbitrary prose-mixed JSON.

**Triage discipline before iterating on the prompt:**

The `.failed/` snapshots ARE the canonical debugging target. Each one preserves the exact prompt sent + the snapshot it was built from. Before changing the prompt:

- Read 5+ `.failed/` snapshots.
- Identify WHICH part of the schema the model is violating (echoed placeholders? extra prose? missing keys? wrong types?).
- Pick the calibration move that addresses the observed failure, not the hypothesized one.

**Why this matters:** the retry-and-defensive-parse pattern is the safety net. Calibration is what keeps the model from needing the safety net every time. Without calibration, the happy path stays empty and the system produces no useful data — just a growing `.failed/` directory.

Sourced from `feedback_haiku_judge_prompt_needs_strict_json_calibration.md`. Pairs with `never-fabricate.md` (calibrate against real `.failed/` evidence, not hypotheses).

## `--json-schema` has a field-count breaking point (Haiku 4.5)

Empirically observed 2026-05-23 during `/system-retro` build: `claude --bare -p --json-schema '{...}'` works reliably on small schemas (≤3 fields, simple types) but returns an EMPTY `result` field on schemas with 6+ fields and mixed types (string + int + bool). The model still spends the API budget (~25s, ~2500 output tokens) — it's reasoning through the structured-output mode but never commits a final answer.

**Failure shape:** the envelope JSON looks healthy (`{"type":"result","result":"",...}`) — no error, no traceback. If your parser doesn't shape-validate the inner `result`, you silently see "judge returned nothing" and treat it as `[]` (legit empty). Same root cause as the wrong-keys case at the top of this file.

**Calibration path that works on 6+-field schemas:**

1. Drop `--json-schema` flag entirely.
2. Add a strict system prompt: `"Your ENTIRE response must be a single JSON object matching this schema. Start with '{' and end with '}'. No prose. No markdown fences."`
3. Inline a literal JSON template in the user prompt (showing all 6 fields with placeholder values).
4. Use the defensive `_extract_json_object()` brace-counter parser to handle any wrapping the model still produces (markdown fences, leading explanation, etc.).
5. Retry-once on bad JSON, then route to `.failed/` snapshot.

This combination reliably produces structured output that strict-mode `--json-schema` silently abandons. Per-call latency drops slightly too (~95s for 20 calls vs ~25s of wasted reasoning on each empty result).

**Boundary:** the 3-field schema in `/consolidate-skills` works fine with `--json-schema`. The 6-field schema in `/system-retro` does not. Treat 4-5 fields as the calibration zone where you should run a 5-call smoke before committing the flag.

Sourced from `feedback_claude_bare_json_schema_field_limit.md`.
