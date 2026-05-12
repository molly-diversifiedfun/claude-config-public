# Git Workflow

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via ~/.claude/settings.json.

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

## Feature Implementation Workflow

1. **Plan First**
   - Use **planner** agent to create implementation plan
   - Identify dependencies and risks
   - Break down into phases

2. **Build + Tests Together**
   - Implementation and tests ship in the SAME commit
   - Build agents must write tests as part of their deliverable
   - Minimum: renders, key states, interactions
   - Verify 80%+ coverage on new code

3. **Code Review BEFORE Final Tests**
   - Use **code-reviewer** agent immediately after writing code
   - Address CRITICAL and HIGH issues FIRST
   - Fix MEDIUM issues when possible
   - Review catches architectural bugs that tests would just lock in
   - Order: implement → review → fix findings → verify/add tests → commit

4. **DoD Autonomously**
   - Run lint (`npm run check`) on changed files
   - Update CLAUDE.md, HANDOFF.md, ADRs, GitHub issues
   - Do NOT list remaining items and ask — just execute them
   - Commit & push with conventional commit messages

5. **Push After Every Commit**
   - Chain `&& git push` onto every `git commit` command — no exceptions
   - Never batch multiple commits before pushing
   - Always `git fetch` before committing to avoid Lovable/remote conflicts
   - If push fails, pull --rebase immediately
