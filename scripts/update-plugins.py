#!/usr/bin/env python3
"""
Plugin updater analyzer. Scans installed plugins for upstream drift.

Environment overrides:
  PLUGIN_UPDATE_INSTALLED_JSON   — path to installed_plugins.json
  PLUGIN_UPDATE_REPORT_DIR       — output directory for markdown reports
  PLUGIN_UPDATE_PER_CALL_TIMEOUT — per-git-call timeout in seconds (default 10)
  PLUGIN_UPDATE_WALL_CAP         — total wall-clock cap in seconds (default 90)
  PLUGIN_UPDATE_WORKERS          — parallel worker count (default 8)
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FuturesTimeout
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


DEFAULT_INSTALLED_JSON = Path.home() / ".claude" / "plugins" / "installed_plugins.json"
DEFAULT_REPORT_DIR = Path.home() / ".claude" / "data" / "plugin-update-reports"


@dataclass(frozen=True)
class InstallRecord:
    plugin_id: str
    scope: str
    version: str
    installed_sha: str
    install_path: str


@dataclass
class ScanResult:
    record: InstallRecord
    bucket: str                  # "DRIFTED" | "CURRENT" | "SKIPPED:<reason>"
    remote_sha: str = ""
    stderr_line: str = ""
    detached: bool = False       # True if installed_sha came from rev-parse, not the JSON


def discover(installed_json_path: Path) -> tuple[list[InstallRecord], int]:
    try:
        with installed_json_path.open() as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"discover: cannot read {installed_json_path}: {e}", file=sys.stderr)
        return [], 0

    plugins = data.get("plugins", {})
    seen_install_paths: set[str] = set()
    records: list[InstallRecord] = []
    orphan_count = 0

    for plugin_id, version_records in plugins.items():
        for vr in version_records:
            install_path = vr.get("installPath", "")
            if not install_path:
                continue
            if install_path in seen_install_paths:
                continue
            seen_install_paths.add(install_path)

            if not Path(install_path).is_dir():
                orphan_count += 1
                continue

            records.append(InstallRecord(
                plugin_id=plugin_id,
                scope=vr.get("scope", "unknown"),
                version=vr.get("version", "unknown"),
                installed_sha=vr.get("gitCommitSha", ""),
                install_path=install_path,
            ))

    return records, orphan_count


def _run_git(args: list[str], cwd: Optional[str], timeout: float) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def scan_remote(record: InstallRecord, timeout: float = 10.0) -> ScanResult:
    """Run git remote get-url + ls-remote, classify."""
    # Step 1: get remote URL (also validates that origin is configured)
    try:
        cp = _run_git(["-C", record.install_path, "remote", "get-url", "origin"],
                      cwd=None, timeout=timeout)
    except subprocess.TimeoutExpired:
        return ScanResult(record=record, bucket="SKIPPED:timeout", stderr_line="get-url timeout")
    except FileNotFoundError:
        return ScanResult(record=record, bucket="SKIPPED:no-remote", stderr_line="git not found")

    if cp.returncode != 0:
        first_line = (cp.stderr or "").splitlines()[0] if cp.stderr else ""
        return ScanResult(record=record, bucket="SKIPPED:no-remote", stderr_line=first_line)

    # Step 2: resolve installed SHA (handle missing/detached cases)
    installed_sha = record.installed_sha
    detached = False
    if not installed_sha or len(installed_sha) != 40:
        try:
            cp = _run_git(["-C", record.install_path, "rev-parse", "HEAD"],
                          cwd=None, timeout=timeout)
            if cp.returncode == 0:
                installed_sha = cp.stdout.strip()
                detached = True
        except subprocess.TimeoutExpired:
            return ScanResult(record=record, bucket="SKIPPED:timeout", stderr_line="rev-parse timeout")

    if not installed_sha or len(installed_sha) != 40:
        return ScanResult(record=record, bucket="SKIPPED:no-remote",
                          stderr_line="cannot resolve installed SHA")

    # Step 3: ls-remote
    try:
        cp = _run_git(["-C", record.install_path, "ls-remote", "origin", "HEAD"],
                      cwd=None, timeout=timeout)
    except subprocess.TimeoutExpired:
        return ScanResult(record=record, bucket="SKIPPED:timeout", stderr_line="ls-remote timeout")

    if cp.returncode != 0:
        first_line = (cp.stderr or "").splitlines()[0] if cp.stderr else ""
        return ScanResult(record=record, bucket="SKIPPED:unreachable", stderr_line=first_line)

    # Parse "SHA<TAB>HEAD" from stdout
    stdout = (cp.stdout or "").strip()
    if not stdout:
        return ScanResult(record=record, bucket="SKIPPED:unreachable",
                          stderr_line="empty ls-remote output")

    parts = stdout.split("\t")
    if len(parts) < 2 or len(parts[0]) != 40:
        return ScanResult(record=record, bucket="SKIPPED:unreachable",
                          stderr_line=f"unparseable ls-remote line: {stdout[:80]}")
    remote_sha = parts[0]

    if remote_sha == installed_sha:
        return ScanResult(record=record, bucket="CURRENT",
                          remote_sha=remote_sha, detached=detached)
    return ScanResult(record=record, bucket="DRIFTED",
                      remote_sha=remote_sha, detached=detached)


def scan_all(records: list[InstallRecord], max_workers: int = 8,
             wall_cap: float = 90.0, per_call_timeout: float = 10.0) -> list[ScanResult]:
    """Parallel scan with wall-clock cap. Honors the cap by cancelling pending
    futures on FuturesTimeout — without this, `ThreadPoolExecutor.__exit__`
    waits for in-flight subprocess calls and runtime can exceed wall_cap by
    up to per_call_timeout × (workers - completed)."""
    results: list[ScanResult] = []
    remaining: set[InstallRecord] = set(records)

    pool = ThreadPoolExecutor(max_workers=max_workers)
    try:
        futures = {pool.submit(scan_remote, r, per_call_timeout): r for r in records}
        try:
            for fut in as_completed(futures, timeout=wall_cap):
                rec = futures[fut]
                try:
                    results.append(fut.result())
                except Exception as e:
                    results.append(ScanResult(record=rec, bucket="SKIPPED:unreachable",
                                              stderr_line=f"scan exception: {e}"))
                remaining.discard(rec)
        except FuturesTimeout:
            pass
    finally:
        # cancel_futures=True (Python 3.9+) drops queued-but-not-started work.
        # In-flight subprocess calls are still bounded by per_call_timeout.
        pool.shutdown(wait=False, cancel_futures=True)

    # Anything not completed before wall_cap → SKIPPED:scan-cap
    for rec in remaining:
        results.append(ScanResult(record=rec, bucket="SKIPPED:scan-cap",
                                  stderr_line=f"exceeded {wall_cap}s wall-clock cap"))

    return results


def write_report(results: list[ScanResult], report_dir: Path,
                 orphan_count: int, scan_duration: float) -> Path:
    report_dir.mkdir(parents=True, exist_ok=True)
    iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    path = report_dir / f"{iso}.md"

    drifted = [r for r in results if r.bucket == "DRIFTED"]
    current = [r for r in results if r.bucket == "CURRENT"]
    skipped = [r for r in results if r.bucket.startswith("SKIPPED:")]

    lines: list[str] = []
    lines.append(f"# Plugin Update Report — {iso}")
    lines.append("")
    lines.append(f"- Scanned: {len(results)}")
    lines.append(f"- Drifted: **{len(drifted)}**")
    lines.append(f"- Current: {len(current)}")
    lines.append(f"- Skipped: {len(skipped)}")
    lines.append(f"- Orphaned records filtered: {orphan_count}")
    lines.append(f"- Scan duration: {scan_duration:.1f}s")
    lines.append("")

    if drifted:
        lines.append("## DRIFTED")
        lines.append("")
        lines.append("| Plugin | Scope | Installed | Remote | Update command |")
        lines.append("|---|---|---|---|---|")
        for r in sorted(drifted, key=lambda x: x.record.plugin_id):
            scope = r.record.scope + ("*detached" if r.detached else "")
            lines.append(f"| `{r.record.plugin_id}` | {scope} | `{r.record.installed_sha[:7]}` | `{r.remote_sha[:7]}` | `claude plugin update {r.record.plugin_id}` |")
        lines.append("")
        lines.append("> Note: `claude plugin update` requires a Claude Code restart to apply.")
        lines.append("")

    if current:
        lines.append(f"## CURRENT ({len(current)})")
        lines.append("")
        names = ", ".join(sorted(f"`{r.record.plugin_id}`" for r in current))
        lines.append(names)
        lines.append("")

    if skipped:
        lines.append("## SKIPPED")
        lines.append("")
        lines.append("| Plugin | Reason | Detail |")
        lines.append("|---|---|---|")
        for r in sorted(skipped, key=lambda x: x.record.plugin_id):
            reason = r.bucket.split(":", 1)[1] if ":" in r.bucket else r.bucket
            detail = (r.stderr_line or "")[:120]
            lines.append(f"| `{r.record.plugin_id}` | {reason} | {detail} |")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("Kill switch: `export PLUGIN_UPDATE=off` to disable `/update-plugins`.")
    lines.append(f"Source of truth: `{os.environ.get('PLUGIN_UPDATE_INSTALLED_JSON', DEFAULT_INSTALLED_JSON)}`")
    lines.append("Drift comparison: `git ls-remote origin HEAD` (no fetch performed).")

    path.write_text("\n".join(lines))
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--discovery-only", action="store_true")
    parser.add_argument("--emit-orphan-count", action="store_true")
    args = parser.parse_args()

    installed_json = Path(os.environ.get("PLUGIN_UPDATE_INSTALLED_JSON", DEFAULT_INSTALLED_JSON))
    report_dir = Path(os.environ.get("PLUGIN_UPDATE_REPORT_DIR", DEFAULT_REPORT_DIR))
    per_call_timeout = float(os.environ.get("PLUGIN_UPDATE_PER_CALL_TIMEOUT", "10"))
    wall_cap = float(os.environ.get("PLUGIN_UPDATE_WALL_CAP", "90"))
    workers = int(os.environ.get("PLUGIN_UPDATE_WORKERS", "8"))

    records, orphan_count = discover(installed_json)

    if args.discovery_only:
        if args.emit_orphan_count:
            payload = {"records": [asdict(r) for r in records], "orphan_count": orphan_count}
        else:
            payload = [asdict(r) for r in records]
        print(json.dumps(payload))
        return 0

    start = time.monotonic()
    results = scan_all(records, max_workers=workers, wall_cap=wall_cap,
                       per_call_timeout=per_call_timeout)
    scan_duration = time.monotonic() - start

    report_path = write_report(results, report_dir, orphan_count, scan_duration)

    drifted_records = [r for r in results if r.bucket == "DRIFTED"]
    out = {
        "drifted": len(drifted_records),
        "report_path": str(report_path),
        "drifted_list": [r.record.plugin_id for r in sorted(drifted_records, key=lambda x: x.record.plugin_id)],
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
