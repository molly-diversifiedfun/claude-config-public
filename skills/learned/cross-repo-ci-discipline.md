---
name: cross-repo-ci-discipline
description: When canonical source moves between repos, the auto-sync CI workflows must follow the canonical content to its new repo. Path-triggered workflows in the old repo go inert silently after the watched dir is empty — worse failure mode than visible broken setup. Intra-repo regen needs no CI; cross-repo regen needs a PAT on the canonical repo.
type: learned-pattern
applies-to: [multi-repo, github-actions, canonical-source, refactor, infra-architecture]
projects: [all]
severity: warning
phase: [planning, infra-refactor, monorepo-vs-polyrepo]
trigger: [content-consolidation, source-of-truth-move, repo-archive, ci-workflow-design]
last-validated: 2026-05-23
archetypes: [infra-config, multi-product, build-pipeline]
---

# Cross-Repo CI Lives With Canonical Source

**Origin:** 2026-05-23 Plan A + Plan B for the Ship It System cluster. Three canonical-source moves happened in one session:
- Plan A: <your-product-pipeline> → claude-skills (AI Build Partner kit-files moved out of <your-product-pipeline>)
- Plan B: <your-marketing-stack> → <your-product-pipeline>/extensions/ (Marketing OS folded into <your-product-pipeline> from standalone repo)
- (Implicit Plan C, did not happen) <your-product-pipeline>/extensions/ → claude-skills (rejected; kept intra-repo)

Each move forced a CI decision: where does the propagation workflow live?

## The rule

When content moves from repo A → repo B as the new canonical source:

1. **Inventory every cron/path-triggered workflow that watches the OLD source path.** Each one needs an explicit fate.
2. **Default to: delete from A, create fresh in B.** The new workflows fire on push to B's canonical paths, check out consumer repos via PAT, run build/sync scripts (also moved to B), open PRs to consumers.
3. **If source-and-consumer end up in the SAME repo** (intra-repo regen, like Plan B's <your-marketing-stack> → <your-product-pipeline>/extensions/ → <your-product-pipeline>/skills/<your-marketing-stack>-skill/): no GitHub Actions needed for propagation. Manual local scripts are sufficient; any contributor or hire can run them after edits without secret-config friction.

## Why path-triggers in the old repo are the silent-failure mode

A workflow with `on: push: paths: ['ai-build-partner-kit/**']` watching a path that no longer exists in the repo:
- Never fires automatically (no commits ever touch that path)
- `workflow_dispatch` manual fallback fails at runtime: `cp <your-product-pipeline>/ai-build-partner-kit/00-*.md ...` exits non-zero because the source files are gone
- No GitHub UI signal that the workflow is broken — just an empty Actions runs list

This is strictly worse than deleting the workflow. A deleted workflow is visible in git history; an inert workflow looks "still configured" but produces nothing. Future contributors see the YAML and assume sync is automatic.

## Why cross-repo workflows from the old location are also wrong

Updating the OLD-location workflow to checkout the NEW canonical repo via PAT seems tempting (less moving). But:
- PAT setup overhead in repo A for content that's no longer in repo A
- Two repos to maintain the workflow YAML in: A holds the workflow, B holds the source
- Debugging cross-repo CI from the consumer side is confusing — "why is repo A's CI involved in syncing B → consumer?"

The canonical-source repo should be the trigger origin. Source drives consumers.

## Concrete pattern (PR-based cross-repo sync)

```yaml
# In repo B (canonical), watching B's own paths
on:
  push:
    branches: [main]
    paths:
      - 'canonical-content/**'
      - 'scripts/build-X.sh'
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { path: repo-b }
      - uses: actions/checkout@v4
        with:
          repository: org/consumer-repo
          token: ${{ secrets.CONSUMER_REPO_PAT }}
          path: consumer-repo
      - name: Run build/sync
        env:
          CONSUMER_PATH: ${{ github.workspace }}/consumer-repo
        run: bash repo-b/scripts/build-X.sh
      - uses: peter-evans/create-pull-request@v6
        with:
          path: consumer-repo
          token: ${{ secrets.CONSUMER_REPO_PAT }}
          commit-message: "feat: sync from canonical"
          branch: canonical-sync
          delete-branch: true
```

The PAT is a **fine-grained token** scoped to `Contents:Write` + `Pull-Requests:Write` on the consumer repo ONLY. Never use a classic PAT or org-wide token for this.

## What to document at canonical handoff

When a canonical-source move ships:
1. PAT names + scopes that the new canonical repo expects in its Secrets settings (else workflows fail silently at the `create-pull-request` step).
2. Manual fallback command — exact `bash scripts/build-X.sh` invocation so a contributor without CI access can sync locally.
3. Old workflow paths that were deleted, with brief reason — prevents future "let me restore that sync workflow" reverts.

## Related patterns

- `delegation-discipline.md` — same principle for agent dispatch (work happens where the data lives, not where the orchestrator runs)
- `mempalace-discipline.md` § auto-mine wrapper lives near the data — same pattern for memory infrastructure
- `verify-before-commit.md` — confirm PAT secrets exist before declaring CI-based propagation "done"

Sourced from `feedback_cross_repo_ci_lives_with_canonical_source.md`. Three concrete data points in one session: Plan A (CI to claude-skills), Plan B (no CI, intra-repo), and the rejected Plan-C-shape (cross-repo from old location).
