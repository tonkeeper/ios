#!/usr/bin/env python3
"""Stamp the shared Maestro API HTTP runtime into every consumer script.

Maestro `runScript` has no import mechanism: each script runs in isolation and
only `output` crosses steps. So the shared HTTP helpers cannot live in one file
that the others import. Instead, `scripts/api/_api_runtime.js` is the single
source of truth and its content is stamped verbatim into every other
`scripts/api/**/*.js` between the markers:

    // >>> api-runtime ...
    ... generated helpers ...
    // <<< api-runtime

Edit `_api_runtime.js`, then run `make maestro_api_sync`. CI runs this with
`--check` to fail if any consumer has drifted from the source.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

API_DIR = Path(__file__).resolve().parent.parent / "api"
SOURCE = API_DIR / "_api_runtime.js"

BEGIN = "// >>> api-runtime"
END = "// <<< api-runtime"
BEGIN_LINE = (
    f"{BEGIN} (generated from scripts/api/_api_runtime.js; "
    "DO NOT EDIT — run `make maestro_api_sync`)"
)

# Matches the whole marked region (markers included), across lines.
REGION_RE = re.compile(
    r"^// >>> api-runtime.*?^// <<< api-runtime$",
    re.MULTILINE | re.DOTALL,
)


def _stamped_block() -> str:
    runtime = SOURCE.read_text().strip("\n")
    return f"{BEGIN_LINE}\n{runtime}\n{END}"


def _consumers() -> list[Path]:
    return sorted(
        p
        for p in API_DIR.rglob("*.js")
        if p.resolve() != SOURCE.resolve()
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if any consumer is out of sync (no writes).",
    )
    args = parser.parse_args()

    if not SOURCE.exists():
        print(f"error: missing source {SOURCE}", file=sys.stderr)
        return 2

    block = _stamped_block()
    drifted: list[Path] = []
    missing_markers: list[Path] = []
    updated: list[Path] = []

    for path in _consumers():
        text = path.read_text()
        if BEGIN not in text or END not in text:
            missing_markers.append(path)
            continue
        new_text = REGION_RE.sub(lambda _: block, text, count=1)
        if new_text == text:
            continue
        if args.check:
            drifted.append(path)
        else:
            path.write_text(new_text)
            updated.append(path)

    if missing_markers:
        rel = ", ".join(str(p.relative_to(API_DIR)) for p in missing_markers)
        print(f"warning: no api-runtime markers, skipped: {rel}", file=sys.stderr)

    if args.check:
        if drifted:
            rel = "\n  ".join(str(p) for p in drifted)
            print(
                "error: api-runtime out of sync. Run `make maestro_api_sync`.\n  "
                + rel,
                file=sys.stderr,
            )
            return 1
        print("api-runtime: all consumers in sync")
        return 0

    if updated:
        for p in updated:
            print(f"synced {p.relative_to(API_DIR.parent.parent.parent)}")
    else:
        print("api-runtime: nothing to update")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
