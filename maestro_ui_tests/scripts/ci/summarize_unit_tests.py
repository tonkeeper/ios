#!/usr/bin/env python3
"""Render a Markdown summary of a unit-test run for the GitHub job summary.

Reads the JUnit report produced by xcbeautify and the xcodebuild exit code,
and prints a pass/fail header plus the list of failed test cases to stdout.
Report-only: never exits non-zero (the unit-tests-gate job enforces the result).
"""
from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def failed_test_names(junit_path: Path) -> list[str] | None:
    """Return failed-test identifiers, or None when the report can't be parsed."""
    try:
        root = ET.parse(junit_path).getroot()
    except Exception as exc:  # noqa: BLE001 - report-only
        print(f"_No JUnit report parsed ({exc})._")
        return None
    failed: list[str] = []
    for case in root.iter("testcase"):
        if case.find("failure") is not None or case.find("error") is not None:
            cls = case.get("classname", "")
            name = case.get("name", "")
            failed.append(f"{cls}.{name}" if cls else name)
    return failed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--junit", type=Path, required=True)
    ap.add_argument("--exit-code", type=int, required=True)
    args = ap.parse_args()

    if args.exit_code == 0:
        print("### ✅ Unit tests passed")
    else:
        print(f"### ❌ Unit tests failed (exit {args.exit_code})")
    print("")

    failed = failed_test_names(args.junit)
    if failed is None:
        return 0
    if failed:
        print(f"**{len(failed)} failed test(s):**")
        print("")
        for name in failed:
            print(f"- `{name}`")
    else:
        print("_No failing test cases in the JUnit report._")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
