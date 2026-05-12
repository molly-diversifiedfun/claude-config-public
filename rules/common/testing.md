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

## E2E Auth Pattern

E2E tests authenticate via Supabase Auth API token injection, NOT browser form filling.
- Auth setup: `e2e/auth.setup.ts` calls `/auth/v1/token`, injects session into localStorage
- Never create Supabase test users via raw SQL INSERT — use the Auth API `/auth/v1/signup`
- See `e2e/README.md` for full setup docs

## Agent Support

- **tdd-guide** - Use PROACTIVELY for new features, enforces write-tests-first
