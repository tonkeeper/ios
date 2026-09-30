#!/usr/bin/env python3
"""
Parse maestro_ui_tests/config.yaml and emit GitHub Actions outputs.

One cluster (``multichain``), one simulator build. Shard layout:
  flows/multichain/<shard>/*  →  shard id ``<shard>``

Every shard runs on one funded wallet. ``ton_wallet_shards`` lists the sections
imported with the TON seed (MAESTRO_WALLET_WITH_MONEY*); the rest use the
multichain seed (MAESTRO_MC_WALLET_MONEY*). The matrix carries the choice as
``wallet: ton | multichain`` so the workflow can map the secrets per shard.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - CI installs PyYAML in discover job
    yaml = None  # type: ignore[assignment]

CLUSTER = "multichain"
FLOW_RE = re.compile(r"^flows/multichain/([^/*]+)/\*$")
WALLET_TON = "ton"
WALLET_MULTICHAIN = "multichain"


def _load_config(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if yaml is not None:
        data = yaml.safe_load(text)
        if not isinstance(data, dict):
            raise ValueError(f"{path}: expected mapping at root")
        return data
    raise RuntimeError("PyYAML is required; install with: pip install pyyaml")


def _section_names(cluster_cfg: dict, key: str) -> set[str]:
    raw = cluster_cfg.get(key) or []
    if not isinstance(raw, list):
        raise ValueError(f"{key} must be a list of section names")
    return {str(item).strip() for item in raw if str(item).strip()}


def _shard_entries(
    patterns: list[str],
    repo_root: Path,
    skip_auto_rerun: set[str],
    ton_wallet_shards: set[str],
) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    seen: set[str] = set()

    for raw in patterns:
        pattern = str(raw).strip().strip("'\"")
        if not pattern:
            continue

        match = FLOW_RE.match(pattern)
        if not match:
            raise ValueError(
                f"{CLUSTER} cluster: expected 'flows/multichain/<shard>/*', got {pattern!r}"
            )
        shard = match.group(1)
        rel_path = f"flows/multichain/{shard}"

        flow_dir = repo_root / "maestro_ui_tests" / rel_path
        if not flow_dir.is_dir():
            raise FileNotFoundError(f"Flow folder missing on disk: {flow_dir}")

        if shard in seen:
            continue
        seen.add(shard)
        entry: dict[str, object] = {
            "id": shard,
            "path": rel_path,
            "cluster": CLUSTER,
            "label": shard,
            "wallet": WALLET_TON if shard in ton_wallet_shards else WALLET_MULTICHAIN,
        }
        if shard in skip_auto_rerun:
            entry["skip_auto_rerun"] = True
        entries.append(entry)

    for key, names in (("skip_auto_rerun", skip_auto_rerun), ("ton_wallet_shards", ton_wallet_shards)):
        unknown = sorted(names - seen)
        if unknown:
            raise ValueError(f"{CLUSTER} {key} names not in flows: {', '.join(unknown)}")

    entries.sort(key=lambda item: str(item["id"]))
    return entries


def discover(repo_root: Path, config_path: Path) -> dict[str, object]:
    data = _load_config(config_path)
    clusters = data.get("clusters")
    if not isinstance(clusters, dict):
        raise ValueError(f"{config_path}: missing 'clusters' mapping")
    if set(clusters) != {CLUSTER}:
        raise ValueError(
            f"{config_path}: expected exactly one cluster {CLUSTER!r}, got {sorted(clusters)}"
        )
    cluster_cfg = clusters[CLUSTER]
    if not isinstance(cluster_cfg, dict):
        raise ValueError(f"{config_path}: cluster {CLUSTER!r} must be a mapping")
    flows = cluster_cfg.get("flows") or []
    if not isinstance(flows, list):
        raise ValueError(f"{config_path}: clusters.{CLUSTER}.flows must be a list")

    shards = _shard_entries(
        [str(x) for x in flows],
        repo_root,
        skip_auto_rerun=_section_names(cluster_cfg, "skip_auto_rerun"),
        ton_wallet_shards=_section_names(cluster_cfg, "ton_wallet_shards"),
    )
    if not shards:
        raise ValueError(f"{config_path}: {CLUSTER} cluster has no shards")

    return {
        "gate_pipeline": bool(cluster_cfg.get("gate_pipeline", False)),
        "build_artifact": str(cluster_cfg.get("build_artifact") or ""),
        "feature_flags": _cluster_feature_flags(cluster_cfg, config_path),
        "shards": shards,
    }


def _cluster_feature_flags(cluster_cfg: dict, config_path: Path) -> dict:
    """Load cluster flag overlay: inline YAML or a JSON file (same shape as the secret)."""
    inline = cluster_cfg.get("feature_flags") or {}
    file_name = cluster_cfg.get("feature_flags_file")
    if file_name:
        if inline:
            raise ValueError(
                f"{config_path}: cannot set both feature_flags and feature_flags_file"
            )
        flags_path = (config_path.parent / str(file_name)).resolve()
        try:
            data = json.loads(flags_path.read_text(encoding="utf-8"))
        except FileNotFoundError as exc:
            raise ValueError(f"{config_path}: feature_flags_file not found: {flags_path}") from exc
        except json.JSONDecodeError as exc:
            raise ValueError(f"{flags_path}: not valid JSON: {exc}") from exc
        if not isinstance(data, dict):
            raise ValueError(f"{flags_path}: feature flags file must be a JSON object")
        return data
    if inline and not isinstance(inline, dict):
        raise ValueError(f"{config_path}: feature_flags must be a mapping")
    return inline if isinstance(inline, dict) else {}


def main() -> int:
    ap = argparse.ArgumentParser(description="Discover Maestro CI shards.")
    ap.add_argument(
        "--config",
        type=Path,
        default=Path("maestro_ui_tests/config.yaml"),
        help="Path to maestro config.yaml",
    )
    ap.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root",
    )
    ap.add_argument(
        "--github-output",
        action="store_true",
        help="Write shards / has_shards / build_artifact outputs for GHA",
    )
    ap.add_argument(
        "--json-out",
        type=Path,
        default=None,
        help="Optional path to write full discovery JSON",
    )
    args = ap.parse_args()

    repo_root = args.repo_root.resolve()
    config_path = args.config if args.config.is_absolute() else repo_root / args.config
    discovered = discover(repo_root, config_path)
    shards = discovered["shards"]

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(discovered, indent=2) + "\n", encoding="utf-8")

    if args.github_output:
        github_output = os.environ.get("GITHUB_OUTPUT")
        if not github_output:
            print("discover_maestro_clusters: --github-output requires GITHUB_OUTPUT", file=sys.stderr)
            return 1
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.write(f"shards={json.dumps(shards, separators=(',', ':'))}\n")
            fh.write(f"has_shards={'true' if shards else 'false'}\n")
            fh.write(f"build_artifact={discovered['build_artifact']}\n")
    else:
        print(json.dumps(discovered, indent=2))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
