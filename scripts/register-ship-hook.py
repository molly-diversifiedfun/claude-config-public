#!/usr/bin/env python3
"""Register ship-phase-gate.sh in ~/.claude/settings.json under hooks.PostToolUse.

Idempotent: prints "already registered" if the hook is already present.
"""
import json
import pathlib

p = pathlib.Path.home() / ".claude/settings.json"
d = json.loads(p.read_text())
post = d["hooks"]["PostToolUse"]

already = any(
    any(h.get("command", "").endswith("ship-phase-gate.sh") for h in e.get("hooks", []))
    for e in post
)

if not already:
    post.append({
        "matcher": "Agent|Bash",
        "hooks": [{
            "type": "command",
            "command": "$HOME/.claude/hooks/ship-phase-gate.sh",
        }],
    })
    p.write_text(json.dumps(d, indent=2))
    print("registered")
else:
    print("already registered")
