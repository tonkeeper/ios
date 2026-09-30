#!/usr/bin/env python3
"""
Parse Maestro verbose CLI logs (same format as summarize_maestro_log.py).
Shared by summarize_maestro_log.py and list_failed_maestro_flow_paths.py.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path


TS_RE = re.compile(r"^(\d{2}:\d{2}:\d{2}\.\d+)\s+")
# Slf4j examples:
# - "... TestSuiteInteractor - Running flow swap_test"
# - "... TestRunner.runSingle...: Running flow swap_test.yaml..."
# Maestro uses: logger.info("$shardPrefix Running flow $flowName") where
# flowName = yaml top-level `name` if set, else file basename without .yaml (see TestSuiteInteractor.kt).
# Capture must allow spaces, slashes, unicode — not only [A-Za-z0-9_.\-].
RUN_FLOW_RE = re.compile(
    r".*(?:TestSuiteInteractor|TestRunner).*Running flow\s+(.+?)(?:\.yaml)?\.{0,3}\s*$"
)
# Orchestra logs: logger.error("[Command execution] CommandFailed: ...")
COMMAND_FAILED_RE = re.compile(r"\[Command execution\] CommandFailed:\s*(.+)$")
# Older / alternate layouts (keep for logs from other Maestro versions).
COMMAND_FAILED_LEGACY_RE = re.compile(
    r"maestro\.orchestra\.Orchestra\.executeCommands:.*CommandFailed:\s*(.*)$"
)
ORCHESTRA_COMMAND_FAILED_ANYWHERE = re.compile(
    r"(?:\[Command execution\] CommandFailed:|"
    r"maestro\.orchestra\.Orchestra\.executeCommands:.*CommandFailed:)\s*(.+)$",
    flags=re.MULTILINE,
)
# INFO: onCommandFailed -> "${shardPrefix}${command.description()} FAILED"
# Current CLI: "...MaestroCommandRunner.runCommands$lambda$4: Assert ... FAILED"
# Maestro 2.6+ slf4j: "...TestSuiteInteractor.runFlow$...: Assert ... FAILED"
# Older layouts: "...CliConsoleListener.onCommandFinished: ... FAILED",
# "...TestSuiteInteractor - Assert ... FAILED"
_STEP_LOGGER_NAMES = (
    "MaestroCommandRunner",
    "TestSuiteInteractor",
    "CliConsoleListener",
)
_STEP_STATUSES = ("RUNNING", "COMPLETED", "FAILED", "SKIPPED", "WARNED")
_STEP_LOGGER = rf"(?:{'|'.join(_STEP_LOGGER_NAMES)})"
_STEP_DESC_SEP = r"(?:-\s*|:\s*)"
STEP_FAILED_RE = re.compile(
    rf".*{_STEP_LOGGER}.*{_STEP_DESC_SEP}(.+?)\s+FAILED\s*$"
)
STEP_STATUS_RE = re.compile(
    rf".*{_STEP_LOGGER}.*{_STEP_DESC_SEP}(.+?)\s+"
    rf"({'|'.join(_STEP_STATUSES)})\s*$"
)
FLOW_YAML_IN_PLAN_RE = re.compile(r"flowsToRun=\[([^\]]+)\]")
# CI concatenates per-flow retry logs: "===== RETRY: /abs/path/foo.yaml (exit 1) ====="
RETRY_JOB_HEADER_RE = re.compile(
    r"^===== RETRY:\s*(.+?)\s*\(exit\s+(\d+)\)\s*=====\s*$"
)


# `maestro --verbose` logs whole `CommandMetadata(...)` dumps, so single lines run to ~12 KB.
# The patterns above lead with `.*`, which backtracks quadratically: one non-matching 12 KB line
# costs ~0.3s. Match only after a cheap check the pattern itself requires, so the common line
# is rejected in microseconds without changing what matches.
def match_run_flow(line: str) -> re.Match | None:
    return RUN_FLOW_RE.search(line) if "Running flow" in line else None


def _trailing_status(line: str) -> str:
    parts = line.rsplit(maxsplit=1)
    return parts[1] if len(parts) == 2 else ""


def match_step_failed(line: str) -> re.Match | None:
    return STEP_FAILED_RE.search(line) if _trailing_status(line) == "FAILED" else None


def match_step_status(line: str) -> re.Match | None:
    return STEP_STATUS_RE.search(line) if _trailing_status(line) in _STEP_STATUSES else None


def split_retry_job_log(lines: list[str]) -> list[tuple[str, int, list[str]]]:
    """Split maestro-retry.log into (yaml_path, exit_code, segment_lines) tuples."""
    blocks: list[tuple[str, int, list[str]]] = []
    current_path: str | None = None
    current_exit = 0
    buf: list[str] = []
    for line in lines:
        m = RETRY_JOB_HEADER_RE.match(line.strip())
        if m:
            if current_path is not None:
                blocks.append((current_path, current_exit, buf))
            current_path = m.group(1).strip()
            current_exit = int(m.group(2))
            buf = []
        else:
            buf.append(line)
    if current_path is not None:
        blocks.append((current_path, current_exit, buf))
    return blocks


def flow_result_from_retry_segment(
    yaml_path: str,
    exit_code: int,
    segment_lines: list[str],
    flows_root: Path | None = None,
    preferred_dir: Path | None = None,
) -> FlowResult:
    """
    Build a FlowResult for one ===== RETRY: path (exit N) ===== segment.

    Uses the path from the RETRY header so failed_yaml_line can be resolved even when
    the segment has no ExecutionPlan flowsToRun=… line.
    """
    stem = Path(yaml_path).stem
    preferred = preferred_dir or Path(yaml_path).parent
    parsed = split_by_flows(
        segment_lines, flows_root=flows_root, preferred_dir=preferred
    )
    if parsed:
        fr = parsed[-1]
        fr.name = stem
        if fr.has_error() and (
            fr.failed_yaml_line is None or fr.flow_yaml_file is None
        ):
            enrich_flow_yaml_failure(
                fr,
                segment_lines,
                {stem: yaml_path},
                flows_root,
                preferred_dir=preferred,
            )
        return fr
    if exit_code != 0:
        return FlowResult(
            name=stem,
            start_line=0,
            text="\n".join(segment_lines),
            failures=[f"maestro exit {exit_code}"],
        )
    return FlowResult(name=stem, start_line=0, text="\n".join(segment_lines))


def retry_segment_passed(exit_code: int, segment_lines: list[str]) -> tuple[bool, str | None]:
    """Infer pass/fail for one retry block; optional last error string."""
    fr = flow_result_from_retry_segment("unknown.yaml", exit_code, segment_lines)
    if fr.has_error():
        if fr.failures:
            return False, fr.failures[-1]
        if fr.step_labels:
            return False, fr.step_labels[-1]
        return False, "unknown error"
    return True, None


@dataclass
class FlowResult:
    name: str
    start_line: int
    text: str
    failures: list[str] = field(default_factory=list)
    step_labels: list[str] = field(default_factory=list)
    failed_yaml_line: int | None = None
    flow_yaml_file: str | None = None
    # Wall-clock time of the last FAILED step / CommandFailed line in this flow block
    # (maestro.log local time-of-day). Used to scrub simulator-run.mp4.
    failed_at: datetime | None = None
    started_at: datetime | None = None

    def has_error(self) -> bool:
        return bool(self.failures) or bool(self.step_labels)


def read_log_lines(log_path: Path) -> list[str]:
    raw = log_path.read_text(encoding="utf-8", errors="replace")
    return raw.splitlines()


def iter_flow_start_events(lines: list[str]) -> list[tuple[datetime, str]]:
    """Wall-clock time + flow base name for each 'Running flow …' line (verbose maestro.log)."""
    out: list[tuple[datetime, str]] = []
    for line in lines:
        t = _parse_time(line)
        if not t:
            continue
        m = match_run_flow(line.rstrip("\r\n"))
        if m:
            out.append((t, m.group(1).strip()))
    return out


def extract_flow_yaml_paths(lines: list[str]) -> dict[str, str]:
    """Map flow base name -> yaml path from ExecutionPlan lines in maestro.log."""
    out: dict[str, str] = {}
    for line in lines:
        m = FLOW_YAML_IN_PLAN_RE.search(line)
        if not m:
            continue
        for part in m.group(1).split(","):
            path = part.strip()
            if path.endswith(".yaml"):
                out[Path(path).stem] = path
    return out


def top_level_yaml_command_lines(yaml_path: Path) -> list[int]:
    """1-based line numbers of each top-level command after the YAML document header."""
    lines = yaml_path.read_text(encoding="utf-8", errors="replace").splitlines()
    in_commands = False
    result: list[int] = []
    for i, line in enumerate(lines):
        if line.strip() == "---":
            in_commands = True
            continue
        if not in_commands:
            continue
        if line.startswith("- "):
            result.append(i + 1)
    return result


_FRAMEWORK_STEP_PREFIXES = ("Define variables", "Apply configuration")

# A `retry:` block logs its failed attempts as ordinary "… FAILED" steps; only the
# block's own terminal status says whether the flow actually failed there.
_RETRY_STEP_PREFIX = "Retry "


def _is_retry_step(desc: str) -> bool:
    return desc.startswith(_RETRY_STEP_PREFIX)


def _is_framework_step(desc: str) -> bool:
    return desc.startswith(_FRAMEWORK_STEP_PREFIXES)


def main_flow_failed_step_index(flow_block_lines: list[str]) -> int | None:
    """
    Index of the failing top-level command in the flow YAML (0-based).
    Subflow commands (Run …) are tracked on a stack and excluded from the count.
    """
    subflow_stack: list[str] = []
    completed_at_depth_0 = 0
    retry_depth = 0
    for line in flow_block_lines:
        m = match_step_status(line.strip())
        if not m:
            continue
        desc, status = m.group(1).strip(), m.group(2)
        if _is_framework_step(desc):
            continue
        if _is_retry_step(desc):
            if status == "RUNNING":
                retry_depth += 1
                continue
            retry_depth = max(retry_depth - 1, 0)
            if retry_depth or subflow_stack:
                continue
            if status == "FAILED":
                return completed_at_depth_0
            completed_at_depth_0 += 1
            continue
        if retry_depth:
            continue
        if status == "RUNNING" and desc.startswith("Run "):
            subflow_stack.append(desc)
            continue
        if status in ("COMPLETED", "FAILED", "SKIPPED", "WARNED") and (
            subflow_stack and subflow_stack[-1] == desc
        ):
            subflow_stack.pop()
            if not subflow_stack:
                if status == "FAILED":
                    return completed_at_depth_0
                completed_at_depth_0 += 1
            continue
        if subflow_stack:
            continue
        if status == "COMPLETED":
            completed_at_depth_0 += 1
        elif status == "FAILED":
            return completed_at_depth_0
    return None


def resolve_failed_yaml_line(yaml_path: Path, step_index: int) -> int | None:
    cmd_lines = top_level_yaml_command_lines(yaml_path)
    if 0 <= step_index < len(cmd_lines):
        return cmd_lines[step_index]
    return None


def resolve_flow_yaml_path(
    path_from_log: str,
    flows_root: Path | None = None,
    preferred_dir: Path | None = None,
) -> Path | None:
    candidate = Path(path_from_log)
    if candidate.is_file():
        return candidate

    # Shard flow dir (e.g. …/flows/multichain/staking) disambiguates stems that
    # exist in several shards (staking vs ton_staking).
    if preferred_dir is not None and preferred_dir.is_dir():
        in_preferred = preferred_dir / candidate.name
        if in_preferred.is_file():
            return in_preferred
        preferred_matches = list(preferred_dir.rglob(candidate.name))
        if len(preferred_matches) == 1:
            return preferred_matches[0]

    if flows_root is None:
        return None

    posix = path_from_log.replace("\\", "/")
    marker = "maestro_ui_tests/flows/"
    if marker in posix:
        rel = posix.split(marker, 1)[1]
        nested = flows_root / rel
        if nested.is_file():
            return nested
    # Maestro / CI sometimes logs repo-relative "flows/<cluster>/…"
    if posix.startswith("flows/"):
        nested = flows_root / posix[len("flows/") :]
        if nested.is_file():
            return nested

    by_name = flows_root / candidate.name
    if by_name.is_file():
        return by_name
    matches = list(flows_root.rglob(candidate.name))
    if len(matches) == 1:
        return matches[0]
    return None


def enrich_flow_yaml_failure(
    fr: FlowResult,
    flow_block_lines: list[str],
    flow_yaml_paths: dict[str, str],
    flows_root: Path | None = None,
    preferred_dir: Path | None = None,
) -> None:
    if not fr.has_error():
        return
    yaml_path_s = flow_yaml_paths.get(fr.name)
    if not yaml_path_s:
        return
    yaml_path = resolve_flow_yaml_path(
        yaml_path_s, flows_root, preferred_dir=preferred_dir
    )
    if yaml_path is None:
        return
    step_index = main_flow_failed_step_index(flow_block_lines)
    if step_index is None:
        return
    line_no = resolve_failed_yaml_line(yaml_path, step_index)
    if line_no is None:
        return
    fr.failed_yaml_line = line_no
    fr.flow_yaml_file = yaml_path.name


def split_by_flows(
    lines: list[str],
    flows_root: Path | None = None,
    preferred_dir: Path | None = None,
) -> list[FlowResult]:
    """Split log into segments, one per 'Running flow name'. Pre-flow prefix is dropped."""
    hits: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        m = match_run_flow(line.rstrip("\r\n"))
        if m:
            hits.append((i, m.group(1).strip()))

    if not hits:
        return []

    flow_yaml_paths = extract_flow_yaml_paths(lines)
    out: list[FlowResult] = []
    for j, (start, name) in enumerate(hits):
        end = hits[j + 1][0] if j + 1 < len(hits) else len(lines)
        block = "\n".join(lines[start:end])
        block_lines = lines[start:end]
        failures: list[str] = []
        step_labels: list[str] = []
        failed_at: datetime | None = None
        started_at = _parse_time(block_lines[0]) if block_lines else None
        retry_depth = 0
        for bline in block_lines:
            stripped = bline.strip()
            cm = COMMAND_FAILED_RE.search(stripped) or COMMAND_FAILED_LEGACY_RE.search(
                stripped
            )
            if cm:
                failures.append(cm.group(1).strip())
                failed_at = _parse_time(bline) or failed_at
            st = match_step_status(stripped)
            if st and _is_retry_step(st.group(1).strip()):
                if st.group(2) == "RUNNING":
                    retry_depth += 1
                else:
                    retry_depth = max(retry_depth - 1, 0)
                    if st.group(2) == "FAILED" and not retry_depth:
                        step_labels.append(st.group(1).strip())
                        failed_at = _parse_time(bline) or failed_at
                continue
            if retry_depth:
                continue
            sm = match_step_failed(stripped)
            if sm:
                step_labels.append(sm.group(1).strip())
                failed_at = _parse_time(bline) or failed_at
        fr = FlowResult(
            name=name,
            start_line=start,
            text=block,
            failures=failures,
            step_labels=step_labels,
            failed_at=failed_at,
            started_at=started_at,
        )
        enrich_flow_yaml_failure(
            fr, block_lines, flow_yaml_paths, flows_root, preferred_dir=preferred_dir
        )
        out.append(fr)
    return out


def failed_flow_names(lines: list[str]) -> list[str]:
    return [f.name for f in split_by_flows(lines) if f.has_error()]


def infer_exit_code_from_log(text: str) -> int:
    return 1 if ORCHESTRA_COMMAND_FAILED_ANYWHERE.findall(text) else 0


def wall_clock(lines: list[str]) -> tuple[datetime | None, datetime | None, str]:
    first = last = None
    for line in lines:
        t = _parse_time(line)
        if t:
            if first is None:
                first = t
            last = t
    if first and last and last >= first:
        return first, last, _fmt_duration_s((last - first).total_seconds())
    return first, last, "unknown"


def _parse_time(line: str) -> datetime | None:
    m = TS_RE.match(line)
    if not m:
        return None
    return datetime.strptime(m.group(1), "%H:%M:%S.%f").replace(
        year=2000, month=1, day=1
    )


def _fmt_duration_s(seconds: float) -> str:
    s = int(round(max(0.0, seconds)))
    m, s = divmod(s, 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h}h {m}m {s}s"
    if m:
        return f"{m}m {s}s"
    return f"{s}s"


def _fmt_clock(t: datetime) -> str:
    return t.strftime("%H:%M:%S.%f")[:-3]


def read_record_started_at_epoch(path: Path | None) -> float | None:
    """Read record-started-at.epoch written when simctl recordVideo starts."""
    if path is None or not path.is_file():
        return None
    raw = path.read_text(encoding="utf-8", errors="replace").strip()
    if not raw:
        return None
    try:
        return float(raw.split()[0])
    except ValueError:
        return None


def screencast_offset_s(
    failed_at: datetime,
    *,
    record_started_epoch: float | None = None,
    log_started_at: datetime | None = None,
) -> float | None:
    """
    Seconds into simulator-run.mp4 for a failed_at wall clock from maestro.log.

    Prefer the record-started-at.epoch stamp (recording begins before maestro.log).
    Fall back to the first timestamp in the log when the stamp is missing.
    """
    if record_started_epoch is not None:
        start_dt = datetime.fromtimestamp(record_started_epoch)
        fail_dt = datetime.combine(start_dt.date(), failed_at.time())
        if fail_dt < start_dt:
            fail_dt += timedelta(days=1)
        return max(0.0, (fail_dt - start_dt).total_seconds())
    if log_started_at is not None:
        delta = (failed_at - log_started_at).total_seconds()
        if delta < 0:
            delta += 24 * 3600
        return max(0.0, delta)
    return None


def format_failure_timing(
    fr: FlowResult,
    *,
    record_started_epoch: float | None = None,
    log_started_at: datetime | None = None,
) -> list[str]:
    """Summary lines for scrubbing simulator-run.mp4 to the failing moment."""
    if not fr.has_error() or fr.failed_at is None:
        return []
    offset = screencast_offset_s(
        fr.failed_at,
        record_started_epoch=record_started_epoch,
        log_started_at=log_started_at,
    )
    clock = _fmt_clock(fr.failed_at)
    if offset is None:
        return [f"    failed_at: {clock}"]
    label = "screencast" if record_started_epoch is not None else "screencast≈log"
    return [f"    failed_at: {clock} ({label} {_fmt_duration_s(offset)})"]

