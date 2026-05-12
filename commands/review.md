Launch the **reviewer** agent to review recent changes.

Usage: /review [optional: specific files or git range]

The reviewer will:
1. Examine recent changes (git diff or specified files)
2. Check for security, bugs, performance, and architecture issues
3. Output a structured review report
4. **Read-only** — will not modify any files

Example: /review
Example: /review src/auth/
