#!/usr/bin/env python3
"""Hold the generated analytics event models to the ingestion APIs' limits.

Aptabase validates every event server-side (`EventBody.IsValid`) and refuses one whose property key is
blank or longer than 40 characters. On `/api/v0/event` that is a 400 for the *whole* payload, so a single
over-long key loses every other property of the event with it — which is exactly how Android lost
`launch_app` to `ff_android_is_swapkit_hard_switch_enabled` (41 characters).

`AnalyticsLimits` repairs such a key at runtime, but the models come from the analytics schemas repo, so
the name has to be caught where it enters the codebase: `make analytics` runs this after the sync, and
`make analytics_check` runs it standalone.

swiftlint cannot cover this — `.swiftlint.yml` excludes both generated directories.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

# Aptabase property key; also GA4's event-parameter-name limit. Mirrors
# `AnalyticsLimits.maximumPropertyKeyLength`.
MAX_PROPERTY_KEY = 40
# Aptabase event name (`[Required, StringLength(60)]`). Binding for these models: they never reach
# Firebase, whose own event-name limit is 40 — a name over that is reported as a warning instead.
MAX_EVENT_NAME = 60
MAX_FIREBASE_EVENT_NAME = 40

EVENT_NAME_RE = re.compile(r'var eventName: String = "([^"]*)"')
CODING_KEYS_RE = re.compile(r"enum CodingKeys[^{]*\{(.*?)\n    \}", re.DOTALL)
EXPLICIT_KEY_RE = re.compile(r'^case\s+`?\w+`?\s*=\s*"([^"]*)"')
IMPLICIT_KEY_RE = re.compile(r"^case\s+`?(\w+)`?\s*$")

DEFAULT_DIRECTORIES = (
    "LocalPackages/TKCore/Sources/TKCore/Analytics/Events/Generated",
    "LocalPackages/TKCore/Sources/TKCore/Analytics/Events/Deprecated",
)


def property_keys(source: str) -> list[str]:
    keys: list[str] = []
    for block in CODING_KEYS_RE.finditer(source):
        for raw_line in block.group(1).splitlines():
            line = raw_line.strip()
            explicit = EXPLICIT_KEY_RE.match(line)
            if explicit:
                keys.append(explicit.group(1))
                continue
            implicit = IMPLICIT_KEY_RE.match(line)
            if implicit:
                keys.append(implicit.group(1))
    return keys


def check_file(path: pathlib.Path) -> tuple[list[str], list[str]]:
    source = path.read_text()
    errors: list[str] = []
    warnings: list[str] = []

    for key in property_keys(source):
        # `eventName` is stripped from the payload by `AnalyticsProvider.log` and never sent as a property.
        if key == "eventName":
            continue
        if not key.strip():
            errors.append(f"{path}: blank property key")
        elif len(key) > MAX_PROPERTY_KEY:
            errors.append(
                f"{path}: property key '{key}' is {len(key)} characters, "
                f"Aptabase rejects the whole event over {MAX_PROPERTY_KEY}"
            )

    for name in EVENT_NAME_RE.findall(source):
        if len(name) > MAX_EVENT_NAME:
            errors.append(
                f"{path}: event name '{name}' is {len(name)} characters, over Aptabase's {MAX_EVENT_NAME}"
            )
        elif len(name) > MAX_FIREBASE_EVENT_NAME:
            warnings.append(
                f"{path}: event name '{name}' is {len(name)} characters — fine for Aptabase, but Firebase "
                f"would silently drop it if this event is ever routed there"
            )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "directories",
        nargs="*",
        help=f"directories of generated event models (default: {', '.join(DEFAULT_DIRECTORIES)})",
    )
    args = parser.parse_args()

    repo_root = pathlib.Path(__file__).resolve().parents[2]
    directories = [pathlib.Path(d) for d in args.directories] or [
        repo_root / d for d in DEFAULT_DIRECTORIES
    ]

    errors: list[str] = []
    warnings: list[str] = []
    checked = 0
    for directory in directories:
        for path in sorted(directory.glob("*.swift")):
            checked += 1
            file_errors, file_warnings = check_file(path)
            errors.extend(file_errors)
            warnings.extend(file_warnings)

    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        print(
            f"\n{len(errors)} analytics key limit violation(s). Rename the offending field in the "
            "analytics schemas repo and re-run `make analytics`.",
            file=sys.stderr,
        )
        return 1

    print(f"Analytics key limits OK ({checked} event models)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
