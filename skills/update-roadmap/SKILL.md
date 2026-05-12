---
name: update-roadmap
description: Surgically update roadmap HTML without rewriting the whole file. Mark stories done/partial, add stories, update progress counts. Keeps roadmap.html, roadmap-board.html, and the story map markdown in sync. Trigger on "update roadmap", "mark story done", "add story to roadmap", "update story status".
---

# Update Roadmap

Make targeted edits to roadmap files. No full rewrites.

## Supported Commands

### Mark story done
User: "mark 'Connect Eventbrite' as done in outcome 1"

1. Grep `public/roadmap.html` for the story text
2. Edit: change `story-icon partial` or `story-icon todo` → `story-icon done`
3. Edit: change icon character (`~` or `○`) → `✓` (checkmark entity `&#10003;`)
4. Edit: add `done` class to `.story-text` span
5. Remove any `.story-note` span (notes are for partial/blocked stories)
6. The JS dynamically calculates progress — no manual counter update needed
7. Make the same edit in `public/roadmap-board.html` if it exists
8. Update `docs/designs/roadmap-v3-complete-story-map.md`: change `[~]` or `[ ]` → `[x]` and add `— VERIFIED`

### Mark story partial
User: "mark 'Combined revenue card' as partial with note 'needs POS data'"

1. Grep for the story text
2. Edit: change icon class to `partial`, character to `~`
3. Add or update `.story-note` span: `<span class="story-note">needs POS data</span>`
4. Sync to board view and markdown

### Add a story
User: "add 'Union POS CSV import' to outcome 1 under Now/Sense"

1. Read roadmap.html, find outcome 1's body
2. Find the rollout phase header (`Now`) and vision section
3. Insert a new story div with correct `data-rollout` and `data-vision` attributes:
```html
<div class="story" data-rollout="now" data-vision="sense">
  <span class="story-icon todo">&#9675;</span>
  <span class="story-text">Union POS CSV import</span>
  <span class="vision-badge sense">Sense</span>
</div>
```
4. Add to board view in the correct cell
5. Add to story map markdown under the correct outcome/phase

### Remove a story
User: "remove 'Cross-venue revenue comparison' from outcome 1"

1. Grep for the story text
2. Delete the entire story div
3. Remove from board view and markdown

### Recalculate progress
User: "recalculate all progress counts"

The roadmap.html JS dynamically calculates progress from DOM. If counts look wrong:
1. Check that story icon classes match status (done/partial/todo)
2. Verify the JS `applyFilters()` function is running on page load

## Sync Rules

Every edit MUST be applied to all 3 files:
1. `public/roadmap.html` (list view)
2. `public/roadmap-board.html` (kanban view) — if it exists
3. `docs/designs/roadmap-v3-complete-story-map.md` (source of truth)

If the board view doesn't exist or the story isn't found in it, skip with a note.

## Verification

After each edit:
1. Read back the edited line to confirm the change landed
2. Check that the story appears in the correct rollout/vision section
3. Report what was changed across all files
