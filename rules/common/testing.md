# Testing Requirements

## Minimum Test Coverage: 80%

Test Types (ALL required):
1. **Unit Tests** - Individual functions, utilities, components
2. **Integration Tests** - API endpoints, database operations
3. **E2E Tests** - Critical user flows (framework chosen per language)

## Test-Driven Development

MANDATORY workflow:
1. Write test first (RED)
2. Run test - it should FAIL
3. Write minimal implementation (GREEN)
4. Run test - it should PASS
5. Refactor (IMPROVE)
6. Verify coverage (80%+)

## Troubleshooting Test Failures

1. Use **tdd-guide** agent
2. Check test isolation
3. Verify mocks are correct
4. Fix implementation, not tests (unless tests are wrong)

## Behavioral Specs Before Tests

MANDATORY: Before writing tests for any feature, a behavioral spec MUST exist in `docs/test-specs/`.
- Spec must include persona, pain point, and "As a [role] when I [action] I expect [outcome]" test cases
- Tests without a corresponding spec are coverage farming — they don't catch real regressions
- If no spec exists, write it first. Never skip to test implementation.

## Registry contract testing (NON-NEGOTIABLE)

When a project uses ANY kind of registry pattern — `mcp_registry.py`, `watchers/registry.py`, `processors/registry.py`, `executors/registry.py`, `sweepers/actions.py`, action handlers, plugin registrations, framework auto-discovery — **module-level unit tests are not sufficient**. You MUST also write an integration test that asserts the new module is in the registry's output.

The trap: it is entirely possible for a module to have full passing unit tests + a system prompt that tells the model to use it + complete production code, while never being imported into the registry. The SDK / framework / dispatch loop receives a registry without it. The tool is silently inert.

**The rule:** when adding a new module behind a registry, the SAME commit MUST include:
1. The module itself.
2. The registry registration (the import + the `build_X` call + the dict / list entry).
3. An integration test that calls the registry builder and asserts:
   - The new key is present in the returned set.
   - The projection function (e.g. `to_options_kwargs`, `build_default_registry`) carries it through.
4. **Update the "exhaustive expected set" assertion** if one exists. A test that asserts `set(keys) == {...exact list...}` is a contract surface — its set must include the new key. Half-finished test updates leave the assertion mirroring the bug instead of enforcing the spec.

**Before opening the PR:** grep for the new module name across all `**/registry.py`, `**/mcp_registry.py`, `**/actions.py` files. The grep MUST return at least one hit beyond the module's own definition file.

Source: 2026-05-17 prod incident — `reference/tools/dispatch_investigate.py` shipped with 10 passing unit tests, was named in `reference/prompts/system.md`, and was inert in production for 14+ hours because nothing imported it into `reference/capabilities/mcp_registry.py`. The model's thinking blocks showed it searching for the tool and not finding it. The existing `test_to_options_kwargs_keys` asserted an exact key set that didn't include `dispatch_investigate` — so the test was reflecting the bug, not enforcing the spec, and stayed green.

## Production smoke after deploy

For any change to a tool, surface, or behavior the model invokes: after merge + deploy, exercise the new path in a real conversation and verify a log line / DB row / external API call actually lands. "All tests passed" + "Railway deploy SUCCESS" is not "it works." Skip only for pure docs / refactors with no behavioral surface.

## E2E Auth Pattern

E2E tests authenticate via Supabase Auth API token injection, NOT browser form filling.
- Auth setup: `e2e/auth.setup.ts` calls `/auth/v1/token`, injects session into localStorage
- Never create Supabase test users via raw SQL INSERT — use the Auth API `/auth/v1/signup`
- See `e2e/README.md` for full setup docs

## Agent Support

- **tdd-guide** - Use PROACTIVELY for new features, enforces write-tests-first
