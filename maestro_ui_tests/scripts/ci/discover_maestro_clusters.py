#!/usr/bin/env python3
"""
Parse maestro_ui_tests/config.yaml clusters and emit GitHub Actions outputs.

Shard layout:
  ton-state:  flows/ton-state/<shard>/*
  multichain: flows/multichain/<shard>/*
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

TON_STATE_FLOW_RE = re.compile(r"^flows/ton-state/([^/*]+)/\*$")
MULTICHAIN_FLOW_RE = re.compile(r"^flows/multichain/([^/*]+)/\*$")


def _load_config(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if yaml is not None:
        data = yaml.safe_load(text)
        if not isinstance(data, dict):
            raise ValueError(f"{path}: expected mapping at root")
        return data
    raise RuntimeError("PyYAML is required; install with: pip install pyyaml")


def _skip_auto_rerun_labels(cluster_cfg: dict) -> set[str]:
    raw = cluster_cfg.get("skip_auto_rerun") or []
    if not isinstance(raw, list):
        raise ValueError("skip_auto_rerun must be a list of section names")
    return {str(item).strip() for item in raw if str(item).strip()}


def _shard_entries(
    cluster: str,
    patterns: list[str],
    repo_root: Path,
    skip_auto_rerun: set[str] | None = None,
) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    seen: set[str] = set()
    skip_auto_rerun = skip_auto_rerun or set()

    for raw in patterns:
        pattern = str(raw).strip().strip("'\"")
        if not pattern:
            continue

        if cluster == "multichain":
            match = MULTICHAIN_FLOW_RE.match(pattern)
            if not match:
                raise ValueError(
                    f"multichain cluster: expected 'flows/multichain/<shard>/*', got {pattern!r}"
                )
            shard = match.group(1)
            rel_path = f"flows/multichain/{shard}"
            shard_id = f"multichain-{shard}"
        else:
            match = TON_STATE_FLOW_RE.match(pattern)
            if not match:
                raise ValueError(
                    f"{cluster} cluster: expected 'flows/ton-state/<shard>/*', got {pattern!r}"
                )
            shard = match.group(1)
            rel_path = f"flows/ton-state/{shard}"
            shard_id = shard

        flow_dir = repo_root / "maestro_ui_tests" / rel_path
        if not flow_dir.is_dir():
            raise FileNotFoundError(f"Flow folder missing on disk: {flow_dir}")

        if shard_id in seen:
            continue
        seen.add(shard_id)
        entry: dict[str, object] = {
            "id": shard_id,
            "path": rel_path,
            "cluster": cluster,
            "label": shard,
        }
        if shard in skip_auto_rerun:
            entry["skip_auto_rerun"] = True
        entries.append(entry)

    unknown = sorted(skip_auto_rerun - {str(e["label"]) for e in entries})
    if unknown:
        raise ValueError(
            f"{cluster} skip_auto_rerun names not in flows: {', '.join(unknown)}"
        )

    entries.sort(key=lambda item: str(item["id"]))
    return entries


def discover(repo_root: Path, config_path: Path) -> dict[str, object]:
    data = _load_config(config_path)
    clusters = data.get("clusters")
    if not isinstance(clusters, dict):
        raise ValueError(f"{config_path}: missing 'clusters' mapping")

    result: dict[str, object] = {}
    for cluster_name, cluster_cfg in clusters.items():
        if not isinstance(cluster_cfg, dict):
            raise ValueError(f"{config_path}: cluster {cluster_name!r} must be a mapping")
        flows = cluster_cfg.get("flows") or []
        if not isinstance(flows, list):
            raise ValueError(f"{config_path}: clusters.{cluster_name}.flows must be a list")

        skip_auto_rerun = _skip_auto_rerun_labels(cluster_cfg)
        shards = _shard_entries(
            str(cluster_name),
            [str(x) for x in flows],
            repo_root,
            skip_auto_rerun=skip_auto_rerun,
        )
        result[str(cluster_name)] = {
            "gate_pipeline": bool(cluster_cfg.get("gate_pipeline", False)),
            "build_artifact": str(cluster_cfg.get("build_artifact") or ""),
            "feature_flags": _cluster_feature_flags(cluster_cfg, config_path),
            "shards": shards,
        }

    if "ton-state" not in result:
        raise ValueError(f"{config_path}: required cluster 'ton-state' is missing")

    ton_shards = result["ton-state"]["shards"]  # type: ignore[index]
    if not ton_shards:
        raise ValueError(f"{config_path}: ton-state cluster has no shards")

    return result


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


def _normalize_clusters_filter(raw: str) -> str:
    value = (raw or "all").strip().lower()
    if value not in {"all", "ton-state", "multichain"}:
        raise ValueError(
            f"invalid --clusters {raw!r}; expected one of: all, ton-state, multichain"
        )
    return value


def _apply_clusters_filter(discovered: dict[str, object], clusters: str) -> dict[str, object]:
    """Return a shallow-filtered discovery view for a manual CI clusters choice."""
    if clusters == "all":
        return discovered

    filtered: dict[str, object] = {}
    for name, cfg in discovered.items():
        if not isinstance(cfg, dict):
            continue
        if clusters == "ton-state" and name != "ton-state":
            continue
        if clusters == "multichain" and name != "multichain":
            continue
        filtered[name] = cfg
    return filtered


def main() -> int:
    ap = argparse.ArgumentParser(description="Discover Maestro CI clusters and shards.")
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
        "--clusters",
        default="all",
        help="Which clusters to emit: all | ton-state | multichain (manual CI filter)",
    )
    ap.add_argument(
        "--github-output",
        action="store_true",
        help="Write ton_state_shards / multichain_shards outputs for GHA",
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
    clusters_filter = _normalize_clusters_filter(args.clusters)
    discovered = _apply_clusters_filter(discover(repo_root, config_path), clusters_filter)

    ton_shards = discovered.get("ton-state", {}).get("shards", [])  # type: ignore[union-attr]
    multichain_shards = discovered.get("multichain", {}).get("shards", [])  # type: ignore[union-attr]
    if clusters_filter in {"all", "ton-state"} and not ton_shards:
        raise ValueError(f"{config_path}: ton-state cluster has no shards")
    if clusters_filter == "multichain" and not multichain_shards:
        raise ValueError(f"{config_path}: multichain cluster has no shards")

    build_targets: list[dict[str, object]] = []
    if ton_shards:
        build_targets.append(
            {
                "id": "ton-state",
                "artifact": discovered["ton-state"]["build_artifact"],  # type: ignore[index]
                "ensure_multichain_disabled": True,
                "overlay": discovered["ton-state"]["feature_flags"],  # type: ignore[index]
            }
        )
    if multichain_shards:
        build_targets.append(
            {
                "id": "multichain",
                "artifact": discovered.get("multichain", {}).get("build_artifact"),  # type: ignore[union-attr]
                "ensure_multichain_disabled": False,
                "ensure_multichain_enabled": True,
                "overlay": discovered.get("multichain", {}).get("feature_flags", {}),  # type: ignore[union-attr]
            }
        )

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(discovered, indent=2) + "\n", encoding="utf-8")

    if args.github_output:
        github_output = os.environ.get("GITHUB_OUTPUT")
        if not github_output:
            print("discover_maestro_clusters: --github-output requires GITHUB_OUTPUT", file=sys.stderr)
            return 1
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.write(f"clusters={clusters_filter}\n")
            fh.write(f"ton_state_shards={json.dumps(ton_shards, separators=(',', ':'))}\n")
            fh.write(f"multichain_shards={json.dumps(multichain_shards, separators=(',', ':'))}\n")
            fh.write(f"has_ton_state_shards={'true' if ton_shards else 'false'}\n")
            fh.write(f"has_multichain_shards={'true' if multichain_shards else 'false'}\n")
            fh.write(f"build_targets={json.dumps(build_targets, separators=(',', ':'))}\n")
    else:
        print(json.dumps({"clusters": clusters_filter, **discovered}, indent=2))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
