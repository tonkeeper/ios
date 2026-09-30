#!/usr/bin/env python3
"""
Build a short maestro-ci-summary.txt from a verbose maestro.log (see --debug-output).
Intended for CI: wall clock span, per-flow pass/fail with failure step, suite counts.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from maestro_log_parse import (
    flow_result_from_retry_segment,
    format_failure_timing,
    infer_exit_code_from_log,
    match_step_failed,
    read_log_lines,
    read_record_started_at_epoch,
    split_by_flows,
    split_retry_job_log,
    wall_clock,
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", type=Path, required=True, help="Path to maestro.log")
    ap.add_argument("--out", type=Path, help="Write summary here (default: stdout)")
    ap.add_argument("--flow-group", default="", help="e.g. matrix value 'transactions'")
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
        help="Path to record-started-at.epoch (defaults to sibling of --log)",
    )
    ap.add_argument(
        "--exit",
        type=int,
        default=None,
        help="maestro process exit code (0 = success). If omitted, inferred from Orchestra CommandFailed lines in log",
    )
    args = ap.parse_args()

    preferred_dir = args.flow_dir.resolve() if args.flow_dir is not None else None
    record_epoch_path = args.record_started_at
    if record_epoch_path is None:
        record_epoch_path = args.log.parent / "record-started-at.epoch"
    record_started_epoch = read_record_started_at_epoch(record_epoch_path)

    raw = args.log.read_text(encoding="utf-8", errors="replace")
    lines = read_log_lines(args.log)
    t0, t1, wall = wall_clock(lines)
    retry_blocks = split_retry_job_log(lines)
    if retry_blocks:
        # Keep failed_step / failed_yaml_line / CommandFailed text — the old path
        # collapsed each RETRY segment to a single error string and dropped the rest.
        flows = [
            flow_result_from_retry_segment(
                yaml_path,
                retry_exit,
                seg_lines,
                flows_root=args.flows_root,
                preferred_dir=preferred_dir,
            )
            for yaml_path, retry_exit, seg_lines in retry_blocks
        ]
    else:
        flows = split_by_flows(
            lines, flows_root=args.flows_root, preferred_dir=preferred_dir
        )

    exit_code = args.exit
    if exit_code is None:
        exit_code = infer_exit_code_from_log(raw)

    n_flows = len(flows)
    n_passed = sum(1 for f in flows if not f.has_error())
    n_failed = n_flows - n_passed
    failed_names = [f.name for f in flows if f.has_error()]

    # Verdict is based on parsed flows, not the maestro CLI exit code. The CLI can exit
    # non-zero even when every flow passed (warnings, driver teardown, etc.).
    if n_flows:
        overall = "FAILED" if n_failed > 0 else "PASSED"
    else:
        overall = "FAILED" if exit_code != 0 else "PASSED"

    out_lines: list[str] = [
        "=== Maestro CI summary ===",
    ]
    if args.flow_group:
        out_lines.append(f"flow_group: {args.flow_group}")
    out_lines.append(f"overall: {overall}")
    if exit_code != 0 and n_flows and n_failed == 0:
        out_lines.append(
            f"note: maestro CLI exited {exit_code} but all {n_flows} parsed flow(s) passed"
        )
    if n_flows:
        out_lines.append(
            f"flows: {n_flows} total | {n_passed} passed | {n_failed} failed"
        )
        if failed_names:
            out_lines.append(f"failed_flows: {', '.join(failed_names)}")
        passed_only = [f.name for f in flows if not f.has_error()]
        if passed_only:
            out_lines.append(f"passed_flows: {', '.join(passed_only)}")
    else:
        out_lines.append("flows: 0 parsed (no 'Running flow …' lines in log)")
    if t0 and t1:
        t0s = t0.strftime("%H:%M:%S.%f")[:-3]
        t1s = t1.strftime("%H:%M:%S.%f")[:-3]
        out_lines.append(f"wall_time: {wall} (log span {t0s} – {t1s}, local time)")
    else:
        out_lines.append(f"wall_time: {wall}")
    out_lines.append(f"log: {args.log.name}")
    out_lines.append("")

    out_lines.append("Per flow:")
    for fr in flows:
        st = "FAILED" if fr.has_error() else "PASSED"
        out_lines.append(f"  {fr.name}: {st}")
        if fr.has_error():
            out_lines.extend(
                format_failure_timing(
                    fr,
                    record_started_epoch=record_started_epoch,
                    log_started_at=t0,
                )
            )
            if fr.step_labels:
                out_lines.append(f"    failed_step: {fr.step_labels[-1]}")
            elif fr.text:
                labels = [
                    m.group(1).strip()
                    for line in fr.text.splitlines()
                    if (m := match_step_failed(line.strip()))
                ]
                if labels:
                    out_lines.append(f"    failed_step: {labels[-1]}")
            if fr.failed_yaml_line is not None and fr.flow_yaml_file:
                out_lines.append(
                    f"    failed_yaml_line: {fr.flow_yaml_file}:{fr.failed_yaml_line}"
                )
            if fr.failures:
                out_lines.append(f"    error: {fr.failures[-1]}")
    out_lines.append("")

    text = "\n".join(out_lines) + "\n"
    if args.out:
        args.out.write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
