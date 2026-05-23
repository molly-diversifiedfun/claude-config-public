---
description: Tournament-test N skills on the same task. Modes — default (3 blind), --yolo (1 random underused), --control (1 champion vs 1 yolo, blind).
---

# /bake-off — skill tournament

Arguments: $ARGUMENTS

You are running a skill tournament. The deterministic prefilter has selected mode-specific candidates:

!`bash ~/.claude/scripts/bake-off-prefilter.sh "$ARGUMENTS"`

If $ARGUMENTS is empty OR the prefilter output starts with `# `, respond with the sentinel/usage line directly and stop.

Otherwise, parse the data line `mode|a|b|c|<query>` (the last field is the query; pipe characters in the query are not expected). Then:

## 1. Dispatch K parallel Agent calls

K depends on mode:
- `blind3`: K=3 (Agents for skills A, B, C)
- `yolo1`: K=1 (Agent for skill A; B and C are empty)
- `control2`: K=2 (Agents for skills A=known-good, B=yolo)

Each Agent prompt:
> Use the `<skill-name>` skill. Task: `<query>`. Return ONLY the final output — no preamble, no meta-commentary about the skill.

Dispatch ALL K agents in PARALLEL (single message with K Agent tool calls).

## 2. Render outputs in numbered sections — BLIND (no skill name in headers)

For `blind3`:
```
## Output A
<agent 1 result>

## Output B
<agent 2 result>

## Output C
<agent 3 result>
```

For `yolo1`: a single `## Output` section. For `control2`: `## Output A` + `## Output B`.

If any Agent returned empty/error: render that slot as `_(no output — skill failed)_`. If ≥2 of 3 fail in blind3, abort vote — surface `# Most candidates failed — no result recorded` and skip step 3.

## 3. Vote via AskUserQuestion

Mode-specific options:
- `blind3`: A wins / B wins / C wins / None worked
- `yolo1`: Worked / Partial / Nope / Skip
- `control2`: A wins / B wins / Tie / Neither

## 4. Reveal the mapping AFTER vote

Print: `**A was \`<skill-1>\`. B was \`<skill-2>\`. C was \`<skill-3>\`.**` (slot count varies by mode.)

## 5. Call the recorder (skip when result is Skip OR vote was cancelled)

Build the result JSON object based on the user's vote:
- A wins → `{"kind":"winner","winner_idx":0}`
- B wins → `{"kind":"winner","winner_idx":1}`
- C wins → `{"kind":"winner","winner_idx":2}`
- Worked → `{"kind":"yolo_rating","yolo_rating":"worked"}`
- Partial → `{"kind":"yolo_rating","yolo_rating":"partial"}`
- Nope → `{"kind":"yolo_rating","yolo_rating":"nope"}`
- Tie → `{"kind":"tie"}`
- None worked / Neither → `{"kind":"none_worked"}`
- Skip → SKIP recorder entirely

Determine archetype from the same source the prefilter used (cwd → projects.yaml lookup). For v1, pass `unknown` if you don't have it readily available — the recorder accepts any string.

Invoke the recorder via bash tool. The recorder requires EXACTLY 7 arguments (empty strings for unused slots):

```bash
bash ~/.claude/scripts/bake-off-record.sh '<mode>' '<query>' '<result-json>' '<a>' '<b>' '<c>' '<archetype>'
```

For yolo1: pass `'' ''` for b and c. For control2: pass `''` for c.

## 6. Report

After recorder exits 0, print one line:
> Recorded. <winner-skill> now <wins>/<appearances>. Try `/skills` to see updated rankings.

(Read the wins/appearances from `~/.claude/data/bake-off-stats.tsv` for the winner skill via `awk -F'\t' '$1=="<winner>" {print $3"/"$2}'`.)

If recorder exits ≠ 0: surface `# Stats write conflicted — outputs above, run again to retry recording`.
