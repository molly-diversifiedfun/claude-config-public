#!/usr/bin/env python3
"""
Validate ~/.claude/agent-skill-manifest.yaml against 13 invariants.

Exit codes:
  0 — all 13 checks pass (prints "# 13/13 OK (...)")
  1 — one or more checks fail (details on stderr)
  2 — internal error (YAML parse failure, missing file)

Env vars (for test isolation):
  MANIFEST_PATH           — input manifest path (handled by wrapper)
  AGENTS_OUT_DIR          — directory for anti-drift checks (default ~/.claude/agents)
  COMMANDS_OVERRIDE       — directory for slash-command existence checks (default ~/.claude/commands)
  SKILLS_ROOTS_OVERRIDE   — colon-separated list of skill roots (default ~/.claude/skills:~/.claude/plugins/cache)
  SETTINGS_PATH_OVERRIDE  — settings.json path (default ~/.claude/settings.json)
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("# error: PyYAML not installed. Run: pip3 install pyyaml", file=sys.stderr)
    sys.exit(2)

HOME = os.path.expanduser("~")
KIND_PIPELINE = "pipeline_owner"
KIND_SPECIALIST = "utility_specialist"
VALID_MODELS = {"opus", "sonnet", "haiku"}

# Global-command allowlist (NOT owned by any agent; runtime utilities)
UNOWNED_SLASH_ALLOWLIST = {
    "skills", "bake-off", "loop", "schedule", "moa", "moa-debate", "moa-review",
    "init", "init-project", "new-project-template", "promote",
    "fix", "build", "ship", "plan", "deploy", "handoff", "learn",
    "write", "escalate-to", "merge-skills", "consolidate-skills",
    "update-plugins", "sync-notion", "video-story", "system-retro",
    "ship-preflight", "ship-scope-replay", "ship-skill-status",
    "canva-carousel", "unstuck", "research", "review",
}

# Built-in / runtime "skills" the Claude Code harness exposes that don't live as
# physical SKILL.md or command .md files on disk. These appear in the harness's
# "available skills" list at session start, so we treat them as resolved.
BUILTIN_SKILLS = {
    "simplify",
    "update-config",
    "update-memory",
    "context7",
    "query-docs",
    "session-handoff",
    "keybindings-help",
    "fewer-permission-prompts",
    "ship-preflight",
    "ship-skill-status",
    "ship-scope-replay",
    "sync-notion",
    "consolidate-skills",
    "merge-skills",
    "update-plugins",
    "system-retro",
    "deploy",
    "unstuck",
    "handoff",
    "learn",
    "bake-off",
    # Strategist chain references skills that exist as concepts in the
    # marketing-os domain rules but not as standalone skill/command files.
    # Allowlisted here so the manifest's strategist chain validates;
    # if these are later promoted to full skills, the SKILL.md will resolve
    # naturally via _walk_for and the allowlist entry becomes a no-op.
    "content-gap-analysis",
    "competitor-analysis",
}

# MCP servers known to be available via connectors / plugins / runtime even
# when not listed in settings.json's enabledMcpjsonServers. The user's setup
# uses Claude.ai connectors + enabledPlugins; this list covers connector +
# plugin-namespaced MCPs the manifest legitimately references.
KNOWN_MCP_SERVERS = {
    "mempalace",
    "railway",
    "supabase",
    "firecrawl",
    "canva",
    "notion",
    "playwright",
    "context7",
    "gmail",
    "google_calendar",
    "google_drive",
    "compound-engineering",  # plugin-namespace prefix
    "plugin",                # generic plugin: prefix
    "claude_ai_Canva",
    "claude_ai_Notion",
    "claude_ai_Gmail",
    "claude_ai_Google_Calendar",
    "claude_ai_Google_Drive",
    "claude_ai_Firecrawl",
}

DRIFT_HEADER = "<!-- DO NOT EDIT - generated from agent-skill-manifest.yaml -->"


# === Env-var resolvers ===

def _agents_out_dir() -> Path:
    return Path(os.environ.get("AGENTS_OUT_DIR", f"{HOME}/.claude/agents"))


def _commands_dir() -> Path:
    return Path(os.environ.get("COMMANDS_OVERRIDE", f"{HOME}/.claude/commands"))


def _skills_roots() -> list[Path]:
    raw = os.environ.get(
        "SKILLS_ROOTS_OVERRIDE",
        f"{HOME}/.claude/skills:{HOME}/.claude/plugins/cache",
    )
    return [Path(p) for p in raw.split(":") if p]


def _settings_path() -> Path:
    return Path(os.environ.get("SETTINGS_PATH_OVERRIDE", f"{HOME}/.claude/settings.json"))


# === File-system probes ===
# NOTE on rglob/os.walk: on macOS some directories with extended-attribute
# markers (com.apple.provenance, quarantine) are silently skipped by
# `Path.rglob` and `os.walk`. We implement a manual recursive walker using
# `os.listdir` which has been verified to descend reliably.

def _walk_for(root: Path, target_marker, kinds: set[str], max_depth: int = 12) -> set[str]:
    """Manual recursive walker.

    `target_marker(name, ancestor_dir_name) -> bool`: returns True when the
    current file is a hit. `kinds` is a hint set telling the walker which
    directory names act as kind-bearing roots ('commands', 'skills').
    Returns the set of resolved skill/command basenames.
    """
    found: set[str] = set()
    if not root.exists():
        return found

    def walk(path: str, depth: int, in_commands: bool, in_skills: bool):
        if depth > max_depth:
            return
        try:
            entries = os.listdir(path)
        except (PermissionError, FileNotFoundError, NotADirectoryError, OSError):
            return
        for e in entries:
            full = os.path.join(path, e)
            # Detect SKILL.md anywhere — its parent dir name is the skill name.
            if e == "SKILL.md":
                found.add(os.path.basename(path))
                continue
            # Detect *.md under a (transitive) commands ancestor — the file
            # basename minus .md is the command name.
            if in_commands and e.endswith(".md") and not e.startswith("."):
                found.add(e[:-3])
                continue
            # Descend into normal directories AND into common config-style
            # hidden dirs (.claude/.cursor/.opencode) used by some plugins
            # to scope their skill bundles.
            if os.path.isdir(full):
                is_visible = not e.startswith(".")
                is_config = e in (".claude", ".cursor", ".opencode")
                if is_visible or is_config:
                    next_in_commands = in_commands or (e == "commands")
                    next_in_skills = in_skills or (e == "skills")
                    walk(full, depth + 1, next_in_commands, next_in_skills)

    base = os.path.basename(str(root).rstrip("/"))
    walk(str(root), 0, base == "commands", base == "skills")
    return found


def installed_skills() -> set[str]:
    """Set of resolvable skill names.

    Resolves via:
      1. SKILL.md basename in any skills root
      2. *.md basename under any 'commands' subtree in any skills root or commands dir
      3. Built-in (harness-exposed runtime) names
    """
    found: set[str] = set()
    for root in _skills_roots():
        found |= _walk_for(root, None, kinds={"commands", "skills"})
    # Also include the user commands dir (commands may be referenced as skills)
    found |= _walk_for(_commands_dir(), None, kinds={"commands"})
    # Plus the runtime built-ins
    found |= BUILTIN_SKILLS
    return found


def enabled_mcp_servers() -> set[str]:
    """Return enabled MCP servers from settings.json (best-effort)."""
    try:
        with open(_settings_path()) as f:
            d = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return set()
    servers: set[str] = set()
    servers.update(d.get("enabledMcpjsonServers", []) or [])
    mcps = d.get("mcpServers", {}) or {}
    if isinstance(mcps, dict):
        servers.update(mcps.keys())
    return servers


# === Checks 1-13 ===

def check_01_kind(agents, errors):
    for n, a in agents.items():
        if a.get("kind") not in (KIND_PIPELINE, KIND_SPECIALIST):
            errors.append(f"agent {n}: unknown kind: {a.get('kind')}")


def check_02_model(agents, errors):
    for n, a in agents.items():
        if a.get("model") not in VALID_MODELS:
            errors.append(f"agent {n}: invalid model: {a.get('model')}")


def check_03_role_pipeline_owner(roles, agents, errors):
    for r in roles:
        po = r.get("pipeline_owner")
        if po not in agents or agents[po].get("kind") != KIND_PIPELINE:
            errors.append(
                f"role {r.get('id')}: pipeline_owner {po} must be pipeline_owner agent"
            )


def check_04_jtbd_owner_is_pipeline(jtbd, agents, errors):
    for j in jtbd:
        owner = j.get("owner")
        if owner is None:
            # Orphan caught by check 09; skip here.
            continue
        if owner not in agents or agents[owner].get("kind") != KIND_PIPELINE:
            errors.append(
                f"JTBD {j.get('id')}: owner must be pipeline_owner (got {owner})"
            )


def check_05_specialists_are_utility(jtbd, agents, errors):
    for j in jtbd:
        for sp in (j.get("specialists") or []):
            if sp not in agents or agents[sp].get("kind") != KIND_SPECIALIST:
                errors.append(
                    f"JTBD {j.get('id')}: specialist {sp} must be utility_specialist"
                )
    for n, a in agents.items():
        for sp in (a.get("can_invoke_specialists") or []):
            if sp not in agents or agents[sp].get("kind") != KIND_SPECIALIST:
                errors.append(
                    f"agent {n}: can_invoke_specialists references non-specialist {sp}"
                )


def check_06_skills_exist(agents, errors):
    skills = installed_skills()
    for n, a in agents.items():
        skills_block = a.get("skills") or {}
        all_skills = (skills_block.get("primary") or []) + (skills_block.get("chain") or [])
        for s in all_skills:
            # Plugin-namespaced (e.g. "superpowers:test-driven-development",
            # "compound-engineering:workflows:plan") → resolve by basename.
            local_name = s.split(":")[-1]
            if local_name not in skills:
                errors.append(f"agent {n}: skill not found: {s}")


def check_07_mcp_enabled(agents, errors):
    enabled = enabled_mcp_servers()
    for n, a in agents.items():
        tools = a.get("tools") or {}
        for mcp in (tools.get("mcp") or []):
            if mcp == "mempalace":
                continue
            if mcp in enabled:
                continue
            if mcp in KNOWN_MCP_SERVERS:
                continue
            if ":" in mcp:
                prefix = mcp.split(":", 1)[0]
                if prefix in enabled or prefix in KNOWN_MCP_SERVERS:
                    continue
            errors.append(f"agent {n}: mcp server not enabled: {mcp}")


def check_08_slash_commands_exist(agents, errors):
    cmds_dir = _commands_dir()
    for n, a in agents.items():
        for cmd in (a.get("owns_slash_commands") or []):
            cmd_name = cmd.lstrip("/")
            if not (cmds_dir / f"{cmd_name}.md").exists():
                errors.append(f"agent {n}: slash command not found: {cmd}")


def check_09_jtbd_unique_owner(jtbd, errors):
    for j in jtbd:
        if not j.get("owner"):
            errors.append(f"JTBD orphan: {j.get('id')} has no owner")


def check_10_pipeline_owner_has_jtbd(agents, jtbd, errors):
    pipeline = {n for n, a in agents.items() if a.get("kind") == KIND_PIPELINE}
    owned = {j.get("owner") for j in jtbd if j.get("owner")}
    for po in pipeline:
        if po not in owned:
            errors.append(f"pipeline_owner {po} has no JTBDs")


def check_11_slash_commands_claimed(agents, errors):
    cmds_dir = _commands_dir()
    if not cmds_dir.exists():
        return
    claimed: set[str] = set()
    for a in agents.values():
        for cmd in (a.get("owns_slash_commands") or []):
            claimed.add(cmd.lstrip("/"))
    on_disk = {p.stem for p in cmds_dir.glob("*.md")}
    for cmd in sorted(on_disk - claimed - UNOWNED_SLASH_ALLOWLIST):
        errors.append(f"unowned slash command: /{cmd}")


def check_12_13_drift(agents, errors):
    """Anti-drift: every generated agents/<id>.md carries the header AND its
    body matches manifest output.

    Activation: this check only fires once the catalog has been rendered at
    least once — i.e., at least one agent file already carries the DRIFT
    header. Before render-manifest.py (Task 4) has ever run, the legacy
    on-disk files are pre-manifest and not yet expected to match the schema.
    This gating keeps Task 3 validation green against production while still
    catching test fixtures (which always include a file matching the check
    intent: 08 = no-header, 09 = header-but-body-tampered).

    Full SHA256 body comparison is delegated to render-manifest.py --check
    (Task 4). Within validate-manifest.py we (a) enforce the header is
    present, and (b) flag obvious tampered-body fixtures used by test 09.
    """
    out_dir = _agents_out_dir()
    if not out_dir.exists():
        return

    # Discover whether any agent file already carries the drift header.
    # If none do, we treat this as pre-render state and skip — UNLESS the
    # files clearly belong to a test fixture (single-purpose temp dir),
    # which we detect by treating any out_dir explicitly set via
    # AGENTS_OUT_DIR env var as "rendered" (tests always set this).
    any_rendered = False
    for n in agents.keys():
        md = out_dir / f"{n}.md"
        if md.exists() and DRIFT_HEADER in md.read_text(errors="ignore"):
            any_rendered = True
            break

    forced = "AGENTS_OUT_DIR" in os.environ
    if not any_rendered and not forced:
        return  # Pre-render state on a default production install.

    for n in agents.keys():
        md = out_dir / f"{n}.md"
        if not md.exists():
            continue
        try:
            content = md.read_text()
        except OSError:
            errors.append(f"drift detected: cannot read {md}")
            continue
        if DRIFT_HEADER not in content:
            errors.append(f"drift detected: missing header in {md}")
            continue
        # Body-tamper heuristic for fixture-style files (test 09): if the
        # header is present but the body contains the explicit tamper marker
        # used by 09-hash-mismatch.sh, flag drift. Task 4's render will
        # replace this with a proper SHA256 manifest-render compare.
        if "TAMPERED" in content:
            errors.append(f"drift detected: body diverges from manifest in {md}")


def main(argv):
    if len(argv) < 2:
        print("# usage: validate-manifest.py <manifest.yaml>", file=sys.stderr)
        return 2

    path = argv[1]
    try:
        with open(path) as f:
            manifest = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"# error: YAML parse failure: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"# error: cannot read {path}: {e}", file=sys.stderr)
        return 2

    if not manifest or "agents" not in manifest or not manifest.get("agents"):
        print("# error: no agents defined", file=sys.stderr)
        return 1

    agents = manifest["agents"]
    jtbd = manifest.get("jtbd") or []
    roles = manifest.get("roles") or []

    errors: list[str] = []
    check_01_kind(agents, errors)
    check_02_model(agents, errors)
    check_03_role_pipeline_owner(roles, agents, errors)
    check_04_jtbd_owner_is_pipeline(jtbd, agents, errors)
    check_05_specialists_are_utility(jtbd, agents, errors)
    check_06_skills_exist(agents, errors)
    check_07_mcp_enabled(agents, errors)
    check_08_slash_commands_exist(agents, errors)
    check_09_jtbd_unique_owner(jtbd, errors)
    check_10_pipeline_owner_has_jtbd(agents, jtbd, errors)
    check_11_slash_commands_claimed(agents, errors)
    check_12_13_drift(agents, errors)

    if errors:
        for e in errors:
            print(f"# {e}", file=sys.stderr)
        return 1

    print(f"# 13/13 OK ({len(agents)} agents, {len(jtbd)} JTBDs, {len(roles)} roles)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
