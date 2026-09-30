#!/usr/bin/env python3
"""
Merge prior Maestro CI state (failed workflow attempt) with logs from a GitHub re-run
that executed only previously failed YAML flows.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from maestro_log_parse import (
    FlowResult,
    flow_result_from_retry_segment,
    format_failure_timing,
    read_log_lines,
    read_record_started_at_epoch,
    split_retry_job_log,
    wall_clock,
)


def _flow_error(fr: FlowResult) -> str | None:
    if not fr.has_error():
        return None
    if fr.failures:
        return fr.failures[-1]
    if fr.step_labels:
        return fr.step_labels[-1]
    return "unknown error"


def _append_flow_failure_details(
    lines_out: list[str],
    fr: FlowResult | None,
    err: str | None,
    *,
    record_started_epoch: float | None = None,
    log_started_at=None,
) -> None:
    if fr is not None:
        lines_out.extend(
            format_failure_timing(
                fr,
                record_started_epoch=record_started_epoch,
                log_started_at=log_started_at,
            )
        )
        if fr.step_labels:
            lines_out.append(f"    failed_step: {fr.step_labels[-1]}")
        if fr.failed_yaml_line is not None and fr.flow_yaml_file:
            lines_out.append(
                f"    failed_yaml_line: {fr.flow_yaml_file}:{fr.failed_yaml_line}"
            )
        if fr.failures:
            lines_out.append(f"    error: {fr.failures[-1]}")
            return
    if err:
        lines_out.append(f"    error: {err}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prior-state", type=Path, required=True, help="state.json from previous attempt")
    ap.add_argument("--retry-log", type=Path, required=True, help="maestro-retry.log from the re-run (optional if missing)")
    ap.add_argument("--flow-group", default="")
    ap.add_argument("--exit", type=int, dest="exit_code", required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument(
        "--flows-root",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "flows",
        help="Local maestro_ui_tests/flows root for resolving yaml line numbers",
    )
    ap.add_argument(
        "--flow-dir",
        type=Path,
        default=None,
        help="Shard flow directory (disambiguates stems shared by several shards, e.g. staking vs ton_staking)",
    )
    ap.add_argument(
        "--record-started-at",
        type=Path,
        default=None,
        help="Path to record-started-at.epoch (defaults to sibling of --retry-log)",
    )
    args = ap.parse_args()

    preferred_dir = args.flow_dir.resolve() if args.flow_dir is not None else None

    prior = json.loads(args.prior_state.read_text(encoding="utf-8", errors="replace"))
    flows_prior: list[dict[str, object]] = prior.get("flows", [])

    retry_by_stem: dict[str, FlowResult] = {}
    retry_lines: list[str] = []
    t0 = t1 = None
    wall = "unknown"
    record_started_epoch = None
    if args.retry_log.is_file():
        record_epoch_path = args.record_started_at
        if record_epoch_path is None:
            record_epoch_path = args.retry_log.parent / "record-started-at.epoch"
        record_started_epoch = read_record_started_at_epoch(record_epoch_path)
        retry_lines = read_log_lines(args.retry_log)
        t0, t1, wall = wall_clock(retry_lines)
        for yaml_path, exit_code, seg_lines in split_retry_job_log(retry_lines):
            stem = Path(yaml_path).stem
            retry_by_stem[stem] = flow_result_from_retry_segment(
                yaml_path,
                exit_code,
                seg_lines,
                flows_root=args.flows_root,
                preferred_dir=preferred_dir,
            )

    # (name, status, prior_err, retry FlowResult|None)
    merged_rows: list[tuple[str, str, str | None, FlowResult | None]] = []
    n_fail = 0
    for row in flows_prior:
        name = str(row["name"])
        prev_failed = row.get("status") == "failed"
        prev_err = row.get("error")
        prev_err_s = str(prev_err) if prev_err else None

        if not prev_failed:
            merged_rows.append((name, "PASSED", None, None))
            continue

        if name not in retry_by_stem:
            merged_rows.append(
                (name, "FAILED", prev_err_s or "not re-executed (missing retry log)", None)
            )
            n_fail += 1
            continue

        fr = retry_by_stem[name]
        if not fr.has_error():
            merged_rows.append((name, "PASSED (rerun)", None, None))
        else:
            merged_rows.append((name, "FAILED", _flow_error(fr) or prev_err_s, fr))
            n_fail += 1

    n_total = len(merged_rows)
    n_pass = n_total - n_fail
    overall = "FAILED" if n_fail > 0 else "PASSED"

    lines_out: list[str] = ["=== Maestro CI summary ==="]
    if args.flow_group:
        lines_out.append(f"flow_group: {args.flow_group}")
    lines_out.append(f"overall: {overall}")
    if args.exit_code != 0 and n_fail == 0 and n_total:
        lines_out.append(
            f"note: maestro CLI exited {args.exit_code} but all {n_total} flow(s) passed after re-run"
        )
    lines_out.append("note: GitHub workflow re-run — only previously failed flows were executed")
    lines_out.append(f"flows: {n_total} total | {n_pass} passed | {n_fail} failed")
    failed_names = [n for n, st, _, _ in merged_rows if st == "FAILED"]
    passed_names = [n for n, st, _, _ in merged_rows if st != "FAILED"]
    if failed_names:
        lines_out.append(f"failed_flows: {', '.join(failed_names)}")
    if passed_names:
        lines_out.append(f"passed_flows: {', '.join(passed_names)}")

    if args.retry_log.is_file():
        if t0 and t1:
            t0s = t0.strftime("%H:%M:%S.%f")[:-3]
            t1s = t1.strftime("%H:%M:%S.%f")[:-3]
            lines_out.append(f"wall_time: {wall} (re-run log span {t0s} – {t1s}, local time)")
        else:
            lines_out.append(f"wall_time: {wall}")
        lines_out.append(f"log: {args.retry_log.name}")
    else:
        lines_out.append("wall_time: unknown")
        lines_out.append("log: (missing retry log)")

    lines_out.append("")
    lines_out.append("Per flow:")
    for name, st, err, fr in merged_rows:
        lines_out.append(f"  {name}: {st}")
        if st == "FAILED":
            _append_flow_failure_details(
                lines_out,
                fr,
                err,
                record_started_epoch=record_started_epoch,
                log_started_at=t0,
            )

    lines_out.append("")
    args.out.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
