---
name: openai-responses-api-as-gpt-smoke
description: "When smoke-testing a ChatGPT Custom GPT, use OpenAI Responses API + vector store + file_search — NOT Chat Completions with knowledge crammed into the system prompt. Responses API matches the live GPT runtime exactly: small Instructions always in scope + on-demand vector retrieval. Cheaper AND more honest than cramming."
type: learned-pattern
applies-to: [chatgpt-gpt, smoke-tests, eval-harness, ai-skills, prompt-engineering]
projects: [all]
severity: warning
phase: [test, design, smoke]
last-validated: 2026-05-20
archetypes: [content-pipeline, brand-content, always-on]
---

# OpenAI Responses API Is the Honest Smoke Surface for ChatGPT Custom GPTs

**Origin:** 2026-05-20 paid Ship It Kit GPT ship (`~/github/<your-product-pipeline>/chatgpt-apps/paid-ship-it-kit/`). First smoke ran via the Anthropic API with the full 461KB knowledge bundle crammed into the `system` parameter. Honest in spirit, dishonest in shape — the live GPT runtime doesn't see knowledge as one giant blob.

## The runtime gap

ChatGPT Custom GPTs split context across two surfaces:

| Surface | Size | Attention |
|---|---|---|
| Instructions field | ≤ ~2K tokens | Always in scope, fully attended |
| Knowledge files | Up to ~20 files of any size | Retrieved as chunks on demand via vector search |

A smoke that crams BOTH into the `system` parameter (115K+ tokens) lets the model dilute attention across the giant blob and improvise from training data instead of retrieving the verbatim opening of the matched command file. It UNDER-predicts live performance — every weak result is a result of test infrastructure, not the GPT design. You can't tell whether the bootloader is broken or the test is.

## The mapping

OpenAI's Responses API exposes the exact Custom GPT architecture as a programmatic surface:

| ChatGPT Custom GPT | OpenAI Responses API |
|---|---|
| Instructions field | `instructions=<bootloader_text>` |
| Knowledge files | `tools=[{type: "file_search", vector_store_ids: [vs_id]}]` |
| Multi-turn conversation | `previous_response_id=<id>` chaining |

When the smoke uses Responses API + vector store + file_search:
- Instructions are 2K tokens, fully attended (matches live)
- Knowledge surfaces as 5-15KB chunks via search (matches live)
- Multi-turn state matches live conversation chaining

Passing this smoke ≈ passing the live GPT.

## Empirical (2026-05-20 paid Kit baselines)

| Smoke architecture | gpt-5-chat-latest | gpt-4o | Diagnostic value |
|---|---|---|---|
| Anthropic (crammed system, 461KB) | n/a | n/a | Aggressive emulation; over-penalizes vs live |
| OpenAI Responses (vector store + file_search) | 4/5 | 1/5 | True runtime parity; honest signal |

The Anthropic smoke caught real bootloader gaps but at a noise level that made calibration hard. The Responses smoke was 5/8 → 7/8 over one bootloader fix iteration, with clean signal on which criteria were real-find vs criterion-spec false-negative.

## Cost

| Approach | Per run (5 turns × 2 models) |
|---|---|
| Anthropic crammed system | $3-4 (no prompt cache) |
| OpenAI Responses + vector store | $1-2 |

Vector store creation is a one-time cost (~$0.10). Subsequent runs reuse the cached `vs_id` and pay only for the per-turn `instructions` + `file_search` query fees.

## How to apply

When you ship a ChatGPT Custom GPT (Phase 1 unlisted, public Store, or anything in between):

1. **Build the smoke against Responses API**, not Chat Completions with crammed system. Don't reuse a working Anthropic harness if it cramps knowledge — the architectural shape is wrong.
2. **Upload knowledge via the Files API** (`POST /v1/files`, `purpose=assistants`). One file per knowledge document. Cache the file ids.
3. **Create the vector store from file_ids** (`POST /v1/vector_stores`). Poll for indexing completion (status `completed` or `in_progress` is usable; `failed` requires investigation). Cache `vs_id` locally — re-upload only on `--rebuild-vs` flag.
4. **Per-turn call** `POST /v1/responses` with `instructions=<bootloader>`, `input=<user_turn>`, `tools=[file_search]`, and `previous_response_id` for multi-turn chains.
5. **Judge with the strongest available model** (Claude Sonnet 4.6 has held up well as a cross-provider judge — see [[llm-judge-needs-retry-and-defensive-parse]] for parsing the verdict JSON).

Reference implementation: `~/github/claude-skills/ai-build-partner/tests/dana-smoke-paid-kit-openai.py` (5-turn Dana script) and `dana-smoke-paid-kit-8test.py` (8-test plan scenarios with independent test isolation).

## When to use Chat Completions instead

Almost never, for a ChatGPT GPT smoke. The exception is a tiny GPT with ≤ 8K combined Instructions + Knowledge — then the crammed-system approach won't dilute attention because there's nothing to dilute. Below that threshold, Chat Completions is simpler. Above it, Responses + vector store is the only honest signal.

## Cross-references

- [[global-bootloader-rules-beat-per-file]] — the structural reason why bootloader sizing matters (always in scope vs retrieved on demand)
- [[llm-judge-needs-retry-and-defensive-parse]] — judge-side parsing discipline; pairs with this pattern when the smoke uses an LLM judge
- [[abstract-voice-rules-need-failure-shapes]] — what the smoke surfaces (vague rules) and how to fix them (concrete BANNED shapes)
