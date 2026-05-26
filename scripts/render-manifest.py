#!/usr/bin/env python3
"""
Render ~/.claude/agent-skill-manifest.yaml into agent.md files + skill-directory.md.

Output format: canonical Claude Code subagent spec
(https://code.claude.com/docs/en/sub-agents). Frontmatter contains only the
documented fields the harness recognizes: name, description, model, tools (as
comma-separated string), and skills (block list). All manifest metadata that
doesn't map to a documented field (kind, owns_jtbd, owns_slash_commands, chain
skills, MCP tools, can_invoke_specialists) lives in the markdown body — the
agent's system prompt still knows what it owns, but the loader doesn't choke
on unknown frontmatter fields.

Background: pre-canonical builds emitted nested `tools.built_in` + `skills.primary`
structures + invented fields (`kind`, `owns_jtbd`, etc). Claude Code's subagent
loader silently rejected these files; dispatches to manifest-defined agent
names hard-failed with "Agent type not found". Phase 8.x dogfood Scenario 4
surfaced this. See feedback_phase_8x_agents_dir_not_enumerated.md.

Usage:
  render-manifest.py                          # render everything
  render-manifest.py --agent <name> --to DIR  # render single agent
  render-manifest.py --check                  # compare against current; exit 1 on drift
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("# error: PyYAML not installed", file=sys.stderr)
    sys.exit(2)

HOME = os.path.expanduser("~")
DEFAULT_MANIFEST = f"{HOME}/.claude/agent-skill-manifest.yaml"
DEFAULT_OUT = f"{HOME}/.claude/agents"  # post-Task-7 cutover: canonical agent dir
DEFAULT_SKILL_DIR = f"{HOME}/.claude/docs/skill-directory.md"
HEADER = "<!-- DO NOT EDIT - generated from agent-skill-manifest.yaml -->"


def _body_list(items: list) -> list[str]:
    """Render a markdown bullet list. Empty list returns empty list."""
    return [f"- {x}" for x in items] if items else []


def render_agent(name: str, agent: dict) -> str:
    desc = agent["description"]
    model = agent["model"]
    kind = agent["kind"]

    # Tools: canonical comma-separated string of built-in tools only.
    # MCP tools are inherited by default — agents that need them get them
    # from the main session's MCP server registration. We document them in
    # the body so the agent knows which servers it's expected to use.
    tools_list = (agent.get("tools") or {}).get("built_in") or []
    tools_str = ", ".join(tools_list) if tools_list else ""

    # Skills: canonical block list. Only primary skills are preloaded into
    # context; chain skills are listed in the body as on-demand references.
    primary_skills = (agent.get("skills") or {}).get("primary") or []
    chain_skills = (agent.get("skills") or {}).get("chain") or []

    # Frontmatter MUST start at byte 0 with "---". Claude Code's subagent
    # loader rejects files whose first line is anything else (e.g. a leading
    # HTML comment), silently dropping the agent from the dispatch roster.
    # The DO-NOT-EDIT notice therefore lives as the first BODY line, below
    # the closing delimiter. See feedback_phase_8x_leading_comment_breaks_frontmatter.
    lines = ["---", f"name: {name}", f"description: {desc}", f"model: {model}"]
    if tools_str:
        lines.append(f"tools: {tools_str}")
    if primary_skills:
        lines.append("skills:")
        lines.extend(f"  - {s}" for s in primary_skills)
    lines.append("---")
    lines.append("")

    # Body — DO-NOT-EDIT notice (HTML comment, invisible in rendered markdown)
    # then operating instructions + manifest metadata as readable markdown.
    lines.append(HEADER)
    lines.append("")
    lines.append(f"# {name}")
    lines.append("")
    body_desc = desc if desc.endswith(".") else desc + "."
    lines.append(body_desc)
    lines.append("")

    lines.append("## Role")
    lines.append("")
    role_label = "pipeline owner" if kind == "pipeline_owner" else "utility specialist"
    lines.append(f"You are a **{role_label}** in the Claude Code agent-skill manifest.")
    lines.append("")

    owns_slash = agent.get("owns_slash_commands") or []
    if owns_slash:
        lines.append("## Owns slash commands")
        lines.append("")
        lines.extend(_body_list(owns_slash))
        lines.append("")

    owns_jtbd = agent.get("owns_jtbd") or []
    if owns_jtbd:
        lines.append("## Owns JTBDs")
        lines.append("")
        lines.extend(_body_list(owns_jtbd))
        lines.append("")

    if chain_skills:
        lines.append("## Chain skills (on-demand)")
        lines.append("")
        lines.append("These skills support your work but aren't preloaded. Invoke via the Skill tool when relevant:")
        lines.append("")
        lines.extend(_body_list(chain_skills))
        lines.append("")

    mcp_servers = (agent.get("tools") or {}).get("mcp") or []
    if mcp_servers:
        lines.append("## MCP servers")
        lines.append("")
        lines.append("Inherited from the main session. Expected to use:")
        lines.append("")
        lines.extend(_body_list(mcp_servers))
        lines.append("")

    specialists = agent.get("can_invoke_specialists") or []
    if specialists:
        lines.append("## Can invoke specialists")
        lines.append("")
        lines.append("Dispatch these utility specialists via Task tool when needed:")
        lines.append("")
        lines.extend(_body_list(specialists))
        lines.append("")

    if agent.get("notes"):
        lines.append("## Notes")
        lines.append("")
        lines.append(agent["notes"].rstrip())
        lines.append("")

    # Trim trailing blank lines, keep one.
    while len(lines) > 1 and lines[-1] == "" and lines[-2] == "":
        lines.pop()

    return "\n".join(lines)


def render_skill_directory(manifest: dict) -> str:
    lines = ["# Skill Directory — Roles × JTBD × Skills", "",
             f"**Generated from:** `~/.claude/agent-skill-manifest.yaml` (v{manifest.get('version', 1)})",
             f"**Last updated:** {manifest.get('last_updated', 'unknown')}",
             "",
             HEADER,
             "",
             "## Roles", ""]

    for role in (manifest.get("roles") or []):
        lines.append(f"### {role['id']}")
        lines.append("")
        lines.append(role.get("description", ""))
        lines.append("")
        lines.append(f"**Pipeline owner:** `{role['pipeline_owner']}`")
        lines.append("")
        role_jtbds = [j for j in (manifest.get("jtbd") or []) if j.get("role") == role["id"]]
        if role_jtbds:
            lines.append("| JTBD | Owner | Slash | Skills |")
            lines.append("|---|---|---|---|")
            for j in role_jtbds:
                slash = j.get("slash_command", "—")
                skills_list = j.get("skills") or []
                skills = ", ".join(f"`{s}`" for s in skills_list) or "—"
                lines.append(f"| {j['description']} | `{j['owner']}` | `{slash}` | {skills} |")
            lines.append("")

    lines.append("## Agents")
    lines.append("")
    pipeline = [n for n, a in manifest["agents"].items() if a["kind"] == "pipeline_owner"]
    specialist = [n for n, a in manifest["agents"].items() if a["kind"] == "utility_specialist"]

    lines.append("### Pipeline owners")
    lines.append("")
    for n in pipeline:
        a = manifest["agents"][n]
        lines.append(f"- **{n}** ({a['model']}) — {a['description']}")
    lines.append("")
    lines.append("### Utility specialists")
    lines.append("")
    for n in specialist:
        a = manifest["agents"][n]
        lines.append(f"- **{n}** ({a['model']}) — {a['description']}")
    lines.append("")
    return "\n".join(lines)


def load_manifest(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def cmd_render_all(manifest_path: str, out_dir: str, skill_dir_out: str) -> int:
    m = load_manifest(manifest_path)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, agent in m["agents"].items():
        content = render_agent(name, agent)
        (out / f"{name}.md").write_text(content, encoding="utf-8")
        print(f"# wrote {out / f'{name}.md'}")
    skill_path = Path(skill_dir_out)
    skill_path.parent.mkdir(parents=True, exist_ok=True)
    skill_path.write_text(render_skill_directory(m), encoding="utf-8")
    print(f"# wrote {skill_path}")
    return 0


def cmd_render_single(manifest_path: str, agent_name: str, to_dir: str) -> int:
    m = load_manifest(manifest_path)
    if agent_name not in m["agents"]:
        print(f"# error: agent not found: {agent_name}", file=sys.stderr)
        return 1
    out = Path(to_dir)
    out.mkdir(parents=True, exist_ok=True)
    content = render_agent(agent_name, m["agents"][agent_name])
    (out / f"{agent_name}.md").write_text(content, encoding="utf-8")
    print(f"# wrote {out / f'{agent_name}.md'}")
    return 0


def cmd_check(manifest_path: str, out_dir: str) -> int:
    m = load_manifest(manifest_path)
    out = Path(out_dir)
    drift = 0
    for name, agent in m["agents"].items():
        current = out / f"{name}.md"
        if not current.exists():
            print(f"# missing: {current}", file=sys.stderr)
            drift += 1
            continue
        expected = render_agent(name, agent)
        actual = current.read_text()
        if hashlib.sha256(expected.encode()).hexdigest() != hashlib.sha256(actual.encode()).hexdigest():
            print(f"# drift detected: hash mismatch in {current}", file=sys.stderr)
            drift += 1
    return 0 if drift == 0 else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--agent", help="render a single agent")
    parser.add_argument("--to", default=None, help="output dir override")
    parser.add_argument("--check", action="store_true", help="check drift, do not write")
    args = parser.parse_args()

    manifest_path = os.environ.get("MANIFEST_PATH", DEFAULT_MANIFEST)
    out_dir = args.to or os.environ.get("AGENTS_OUT_DIR", DEFAULT_OUT)
    skill_dir_out = os.environ.get("SKILL_DIR_OUT", DEFAULT_SKILL_DIR)

    if args.check:
        return cmd_check(manifest_path, out_dir)
    if args.agent:
        return cmd_render_single(manifest_path, args.agent, out_dir)
    return cmd_render_all(manifest_path, out_dir, skill_dir_out)


if __name__ == "__main__":
    sys.exit(main())
