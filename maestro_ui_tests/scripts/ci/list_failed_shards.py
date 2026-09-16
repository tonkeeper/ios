#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


SHARD_PREFIX = "maestro-failed-state-"


def _shard_name(failed_paths: Path) -> str | None:
    """Shard from the artifact dir prefix, or state.json flow_group (flat layout)."""
    parent = failed_paths.parent
    if parent.name.startswith(SHARD_PREFIX):
        return parent.name[len(SHARD_PREFIX):] or None
    try:
        data = json.loads((parent / "state.json").read_text(encoding="utf-8", errors="replace"))
        fg = data.get("flow_group")
        return fg.strip() if isinstance(fg, str) and fg.strip() else None
    except (ValueError, OSError):
        return None


def list_failed_shards(root: Path) -> list[str]:
    """Shard names with a non-empty failed_paths.txt.

    actions/download-artifact extracts to a per-shard subdir when multiple
    artifacts match the pattern, but flat into <root> for a single match.
    rglob handles both; shard name comes from the dir prefix or state.json.
    """
    shards: list[str] = []
    for fp in sorted(root.rglob("failed_paths.txt")):
        if not any(l.strip() for l in fp.read_text(encoding="utf-8", errors="replace").splitlines()):
            continue
        shard = _shard_name(fp)
        if shard and shard not in shards:
            shards.append(shard)
        elif not shard:
            print(f"list_failed_shards: cannot resolve shard for {fp}", file=sys.stderr)
    return shards


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, required=True)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    text = json.dumps(list_failed_shards(args.root))
    sys.stdout.write(text + "\n")
    if args.out is not None:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
