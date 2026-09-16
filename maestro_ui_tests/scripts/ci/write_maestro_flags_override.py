#!/usr/bin/env python3
"""Write Tonkeeper/Resources/FlagsOverride.json for Maestro CI builds."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def _load_json_object(raw: str | None, label: str) -> dict[str, Any]:
    if raw is None or not str(raw).strip():
        return {}
    try:
        parsed = json.loads(str(raw))
    except json.JSONDecodeError as exc:
        raise ValueError(f"{label} is not valid JSON: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"{label} must be a JSON object")
    return parsed


def _merge_dicts(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    result = dict(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _merge_dicts(result[key], value)
        else:
            result[key] = value
    return result


def _load_json_file(path: Path | None, label: str) -> dict[str, Any]:
    if path is None:
        return {}
    if not path.is_file():
        raise ValueError(f"{label} not found: {path}")
    return _load_json_object(path.read_text(encoding="utf-8"), label)


def build_flags_override(
    base_json: str | None,
    overlay_json: str | None,
    overlay_json_file: Path | None = None,
) -> dict[str, Any]:
    base = _load_json_object(base_json, "base flags JSON")
    overlay = _merge_dicts(
        _load_json_file(overlay_json_file, "overlay flags file"),
        _load_json_object(overlay_json, "overlay flags JSON"),
    )
    return _merge_dicts(base, overlay)


def _object_at(merged: dict[str, Any], key: str) -> dict[str, Any]:
    value = merged.setdefault(key, {})
    if not isinstance(value, dict):
        raise ValueError(f"{key} must be an object when present")
    return value


def apply_multichain_gate(merged: dict[str, Any], *, enabled: bool) -> None:
    """Force the Firebase multichain flag, which outranks keys/all in dev builds."""
    _object_at(merged, "featureFlags")["multichainEnabled"] = enabled


def main() -> int:
    ap = argparse.ArgumentParser(description="Write FlagsOverride.json for Maestro simulator builds.")
    ap.add_argument(
        "--dest",
        type=Path,
        default=Path("Tonkeeper/Resources/FlagsOverride.json"),
        help="Destination FlagsOverride.json path",
    )
    ap.add_argument(
        "--base-json",
        default=None,
        help="Optional base JSON (e.g. MAESTRO_FEATURE_FLAG_OVERRIDES secret)",
    )
    ap.add_argument(
        "--overlay-json",
        default=None,
        help="Optional overlay JSON merged on top of base",
    )
    ap.add_argument(
        "--overlay-json-file",
        type=Path,
        default=None,
        help="Optional overlay JSON file merged on top of base (same shape as the secret)",
    )
    ap.add_argument(
        "--ensure-multichain-disabled",
        action="store_true",
        help="Force featureFlags.multichainEnabled=false for ton-state builds",
    )
    ap.add_argument(
        "--ensure-multichain-enabled",
        action="store_true",
        help=(
            "Force featureFlags.multichainEnabled=true for multichain builds "
            "(outranks keys/all, so the boot flag does not have to be set)"
        ),
    )
    args = ap.parse_args()

    if args.ensure_multichain_disabled and args.ensure_multichain_enabled:
        raise ValueError("cannot pass both --ensure-multichain-disabled and --ensure-multichain-enabled")

    merged = build_flags_override(args.base_json, args.overlay_json, args.overlay_json_file)
    if args.ensure_multichain_disabled:
        apply_multichain_gate(merged, enabled=False)
    elif args.ensure_multichain_enabled:
        apply_multichain_gate(merged, enabled=True)

    args.dest.parent.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(merged, indent=2, sort_keys=True) + "\n"
    args.dest.write_text(rendered, encoding="utf-8")
    feature_flags = merged.get("featureFlags") if isinstance(merged.get("featureFlags"), dict) else {}
    print(f"Wrote {args.dest} ({len(json.dumps(merged))} bytes)")
    print(f"multichain gate: featureFlags.multichainEnabled={feature_flags.get('multichainEnabled')}")
    print("FlagsOverride.json:")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"write_maestro_flags_override: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
