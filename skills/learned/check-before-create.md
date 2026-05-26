---
name: check-before-create
description: Run ls or glob on target directory before creating any new file — check if a similar file already exists
severity: warning
archetypes: [always-on]
last-validated: 2026-05-26
---

Before creating ANY new file, run `ls` or glob on the target directory first. Check if a file with similar purpose already exists.

**Why:** Creating duplicates when a file already exists causes confusion, merge conflicts, and wasted work. Seen repeatedly across projects.

**How to apply:** Every Write tool call for a new file should be preceded by a directory listing of the parent.
