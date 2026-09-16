#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from maestro_log_parse import (
    read_log_lines,
    retry_segment_passed,
    split_by_flows,
    split_retry_job_log,
)


def _flow_error(fr) -> str | None:
    if not fr.has_error():
        return None
    if fr.failures:
        return fr.failures[-1]
    if fr.step_labels:
        return fr.step_labels[-1]
    return "unknown error"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", type=Path, required=True)
    ap.add_argument("--shard-id", required=True, help="Shard id stored in retry state, e.g. backup")
    ap.add_argument(
        "--flow-dir",
        type=Path,
        required=True,
        help="Directory with flow YAML files (absolute or relative to --repo-root)",
    )
    ap.add_argument(
        "--flow-group",
        default=None,
        help="Deprecated alias for --shard-id (ignored when --shard-id is set)",
    )
    ap.add_argument("--artifacts-dir", type=Path, required=True, help="MAESTRO_CI_ARTIFACTS_DIR")
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()

    root = args.repo_root.resolve()
    art = args.artifacts_dir
    flow_dir = args.flow_dir if args.flow_dir.is_absolute() else root / args.flow_dir
    if not flow_dir.is_dir():
        print(f"write_maestro_github_retry_state: missing flow dir {flow_dir}", file=sys.stderr)
        return 1

    ordered_names = sorted(p.stem for p in flow_dir.glob("*.yaml"))

    log_primary = art / "maestro.log"
    log_primary_missing = not log_primary.is_file()
    if log_primary_missing:
        print(
            "write_maestro_github_retry_state: no maestro.log; "
            "treating the whole shard as failed (CI failed before maestro started)",
            file=sys.stderr,
        )
        first_by_name = {}
    else:
        first_by_name = {f.name: f for f in split_by_flows(read_log_lines(log_primary))}

    retry_by_stem: dict[str, tuple[bool, str | None]] = {}
    log_retry = art / "maestro-retry.log"
    if log_retry.is_file():
        for yaml_path, exit_code, seg_lines in split_retry_job_log(read_log_lines(log_retry)):
            stem = Path(yaml_path).stem
            ok, err = retry_segment_passed(exit_code, seg_lines)
            retry_by_stem[stem] = (ok, err)

    flows_out: list[dict[str, object]] = []
    failed_paths: list[Path] = []

    for name in ordered_names:
        err: str | None = None
        final_failed: bool

        if name in retry_by_stem:
            ok, err = retry_by_stem[name]
            final_failed = not ok
        else:
            fr = first_by_name.get(name)
            if fr is None:
                final_failed = True
                if log_primary_missing:
                    err = "shard CI failed before maestro started"
                else:
                    err = "flow not present in maestro.log"
            else:
                final_failed = fr.has_error()
                if final_failed:
                    err = _flow_error(fr)

        entry: dict[str, object] = {"name": name, "status": "failed" if final_failed else "passed"}
        if err:
            entry["error"] = err
        flows_out.append(entry)

        if final_failed:
            p = flow_dir / f"{name}.yaml"
            if p.is_file():
                failed_paths.append(p.resolve())

    args.out_dir.mkdir(parents=True, exist_ok=True)
    state = {
        "version": 1,
        "flow_group": args.shard_id,
        "flows": flows_out,
    }
    (args.out_dir / "state.json").write_text(
        json.dumps(state, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    fp_text = "\n".join(str(p).replace("\r", "") for p in failed_paths) + ("\n" if failed_paths else "")
    (args.out_dir / "failed_paths.txt").write_text(fp_text, encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
