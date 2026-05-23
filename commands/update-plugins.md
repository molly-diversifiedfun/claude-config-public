---
description: Scan installed plugins for upstream drift via git ls-remote, write a tiered markdown report, and offer interactive `claude plugin update` for drifted plugins.
---

You are running the `/update-plugins` slash command. Your job is to invoke the Python analyzer, present the report, and (if drift > 0) prompt the user for which updates to apply.

## Step 1 — Kill switch + invocation

Run this Bash:

```bash
if [ "${PLUGIN_UPDATE:-on}" = "off" ]; then
    echo "PLUGIN_UPDATE=off — /update-plugins disabled. Unset to re-enable."
    exit 0
fi

# Run analyzer. Final stdout line is the JSON; progress lines (if any) go to stderr.
output=$(python3 ~/.claude/scripts/update-plugins.py 2>&1)
status=$?

if [ "$status" -ne 0 ]; then
    echo "Plugin updater failed (exit $status):" >&2
    echo "$output" >&2
    exit "$status"
fi

# The final non-empty line of stdout is the JSON output line.
json=$(printf '%s\n' "$output" | awk 'NF' | tail -n 1)
drifted=$(printf '%s' "$json" | python3 -c 'import sys,json;print(json.load(sys.stdin)["drifted"])')
report_path=$(printf '%s' "$json" | python3 -c 'import sys,json;print(json.load(sys.stdin)["report_path"])')

echo "Report: $report_path"
echo ""
echo "Drifted: $drifted"

if [ "$drifted" -eq 0 ]; then
    echo "All current. Nothing to apply."
    exit 0
fi

# Print the drifted list, framed for the parent assistant turn to parse.
echo ""
echo "DRIFTED_LIST_BEGIN"
printf '%s\n' "$json" | python3 -c 'import sys,json; [print(p) for p in json.load(sys.stdin)["drifted_list"]]'
echo "DRIFTED_LIST_END"
```

## Step 2 — If drift > 0, prompt the user

After Step 1 prints `DRIFTED_LIST_BEGIN ... DRIFTED_LIST_END`:

1. Extract the plugin IDs between the markers
2. Show the user the first ~10 rows of the DRIFTED section from the report file (read it via the Read tool)
3. Invoke `AskUserQuestion`:
   - Question: "Apply N updates via `claude plugin update`? (Restart required after.)"
   - Options:
     - "Apply all N" — runs `claude plugin update <id>` for every drifted plugin
     - "Select subset" — secondary multi-select prompt with the drifted list
     - "None — just leave the report" — exits

## Step 3 — On selection, apply updates serially

For each chosen plugin ID, run:

```bash
echo "Updating <plugin_id>..."
claude plugin update <plugin_id> 2>&1 | tee -a ~/.claude/logs/plugin-update.log
echo "Exit: $?"
```

Do NOT abort the batch on individual failures — continue, then print a summary:

```
Applied X of N successfully.
Restart Claude Code to load the updates.
```

If any failures, append a short list of failed plugin IDs.

## Notes
- Kill switch: `export PLUGIN_UPDATE=off` disables this command
- Report retained at `~/.claude/data/plugin-update-reports/<ISO>.md` regardless of apply choice
- Apply failures logged to `~/.claude/logs/plugin-update.log`
