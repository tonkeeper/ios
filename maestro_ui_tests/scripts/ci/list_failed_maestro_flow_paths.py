#!/usr/bin/env python3
"""
Resolve failed Maestro flow names from a verbose maestro.log to concrete YAML paths.

Used by CI to re-run only failed flows after a full flow_group directory run failed.

Example:
  python3 list_failed_maestro_flow_paths.py \\
    --log build/maestro-ci-artifacts-transactions/maestro.log \\
    --flow-group transactions \\
    --repo-root .
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from maestro_log_parse import failed_flow_names, read_log_lines


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Print absolute paths to failed flow YAML files (one per line)."
    )
    ap.add_argument("--log", type=Path, required=True, help="Path to maestro.log")
    ap.add_argument(
        "--flow-dir",
        type=Path,
        default=None,
        help="Directory with flow YAML files (absolute or relative to --repo-root)",
    )
    ap.add_argument(
        "--flow-group",
        default=None,
        help="Legacy: subfolder under maestro_ui_tests/flows/ (e.g. transactions)",
    )
    ap.add_argument(
        "--shard-id",
        default=None,
        help="Shard id for logging (defaults to flow-dir name)",
    )
    ap.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root (default: current working directory)",
    )
    args = ap.parse_args()

    lines = read_log_lines(args.log)
    names = failed_flow_names(lines)
    root = args.repo_root.resolve()
    if args.flow_dir is not None:
        flow_dir = args.flow_dir if args.flow_dir.is_absolute() else root / args.flow_dir
    elif args.flow_group:
        flow_dir = root / "maestro_ui_tests" / "flows" / args.flow_group
    else:
        print("list_failed_maestro_flow_paths: --flow-dir or --flow-group is required", file=sys.stderr)
        return 1

    paths: list[Path] = []
    seen: set[str] = set()
    for name in names:
        p = flow_dir / f"{name}.yaml"
        if p.is_file():
            key = str(p.resolve())
            if key not in seen:
                seen.add(key)
                paths.append(p)
        else:
            print(f"list_failed_maestro_flow_paths: missing file for flow {name!r}: {p}", file=sys.stderr)

    for p in paths:
        # One path per line, no CR (Windows runners / mixed checkouts).
        print(str(p.resolve()).replace("\r", ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
