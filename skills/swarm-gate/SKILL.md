---
name: swarm-gate
description: Quality gate after parallel agent waves. Run before committing swarm output. Checks doc freshness, missing ADRs, test sync, CLAUDE.md staleness. Use when you've run multiple parallel agents and are about to commit their combined output.
---

# Swarm Quality Gate

Run this checklist BEFORE committing output from parallel agent waves. Do NOT skip items. Report results as a pass/fail checklist.

## Step 1: Doc Freshness

Run the freshness checker:
```bash
./scripts/doc-freshness.sh
```

If any docs are STALE, list them. Do NOT auto-fix — report what's stale so the user can decide.

## Step 2: Missing ADRs

Check which files changed in the current working tree or last commit:
```bash
git diff --name-only HEAD~1  # or git diff --cached --name-only if not yet committed
```

If ANY of these patterns appear, check for a corresponding NEW ADR in `docs/decisions/`:
- `supabase/functions/*/index.ts` — new edge function needs ADR
- `supabase/migrations/*` — new table/schema change may need ADR
- `vite.config.ts` — build config change needs ADR
- `src/contexts/*` — new provider needs ADR
- `src/lib/featureFlags.ts` — route gating change needs ADR

List any architectural changes without ADRs.

## Step 3: Test Count Sync

Run tests and compare to CLAUDE.md:
```bash
npx vitest run 2>&1 | grep "Tests"
grep "tests" CLAUDE.md | head -3
```

If the numbers don't match, flag it.

## Step 4: New Files Without Tests

Check for new service/hook files without corresponding test files:
```bash
# New services without tests
for f in $(git diff --name-only HEAD~1 | grep "src/services/.*\.ts$" | grep -v ".test."); do
  test_file="${f%.ts}.test.ts"
  if [ ! -f "$test_file" ]; then echo "NO TEST: $f"; fi
done

# New hooks without tests
for f in $(git diff --name-only HEAD~1 | grep "src/hooks/.*\.ts$" | grep -v ".test."); do
  test_file="${f%.ts}.test.ts"
  if [ ! -f "$test_file" ]; then echo "NO TEST: $f"; fi
done
```

## Step 5: CLAUDE.md Staleness

Check these counts in CLAUDE.md against reality:
- Edge function count: `ls supabase/functions/ | grep -v _shared | wc -l`
- Table count: grep the types.ts or count migrations
- Test count: from Step 3

## Step 6: Report

Output a checklist:
```
## Swarm Gate Results
- [ ] Doc freshness: X stale / Y fresh
- [ ] Missing ADRs: list or "none"
- [ ] Test count: CLAUDE.md says X, actual Y
- [ ] New files without tests: list or "none"
- [ ] CLAUDE.md counts: match / stale

VERDICT: PASS / FAIL (list what needs fixing)
```

If FAIL, do NOT commit until the user approves or fixes are applied.
