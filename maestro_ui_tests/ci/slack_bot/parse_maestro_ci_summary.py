#!/usr/bin/env python3
"""
Parse maestro-ci-summary.txt produced by summarize_maestro_log.py / merge_maestro_github_rerun_summary.py.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path


OVERALL_RE = re.compile(r"^overall:\s*(PASSED|FAILED)\s*$", re.I)
OVERALL_LEGACY_RE = re.compile(r"^overall:\s*(PASSED|FAILED)(?:\s*\(exit\s+(\d+)\))?", re.I)
ARTIFACTS_URL_RE = re.compile(r"^artifacts_url:\s*(.+)$")
ARTIFACT_NAME_RE = re.compile(r"^artifact_name:\s*(.+)$")
FLOW_GROUP_RE = re.compile(r"^flow_group:\s*(.+)$")
FLOWS_COUNTS_RE = re.compile(
    r"^flows:\s*(\d+)\s+total\s*\|\s*(\d+)\s+passed\s*\|\s*(\d+)\s+failed$"
)
FAILED_FLOWS_RE = re.compile(r"^failed_flows:\s*(.+)$")
PASSED_FLOWS_RE = re.compile(r"^passed_flows:\s*(.+)$")
PER_FLOW_HEADER_RE = re.compile(r"^Per flow:\s*$")
FLOW_LINE_RE = re.compile(r"^  (?!  )(.+):\s*(.+)$")
INDENT_DETAIL_RE = re.compile(r"^    (\w+):\s*(.+)$")
RETRY_SECTION_HEADER_RE = re.compile(r"^=== Retry \(.*?\) ===\s*$")


@dataclass
class FlowSummary:
    name: str
    status: str
    failed_step: str | None = None
    failed_yaml_line: str | None = None
    error: str | None = None

    @property
    def is_failed(self) -> bool:
        return self.status.upper().startswith("FAILED")


@dataclass
class MaestroCiSummary:
    path: Path
    flow_group: str = ""
    overall: str = "UNKNOWN"
    exit_code: int | None = None
    total: int = 0
    passed: int = 0
    failed: int = 0
    failed_flows: list[str] = field(default_factory=list)
    passed_flows: list[str] = field(default_factory=list)
    flows: list[FlowSummary] = field(default_factory=list)
    artifacts_url: str = ""
    artifact_name: str = ""

    @property
    def is_passed(self) -> bool:
        if self.failed > 0:
            return False
        if self.flows:
            return not any(flow.is_failed for flow in self.flows)
        return self.overall.upper() == "PASSED"


def _split_csv(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def parse_maestro_ci_summary(text: str, path: Path | None = None) -> MaestroCiSummary:
    summary = MaestroCiSummary(path=path or Path("maestro-ci-summary.txt"))
    in_per_flow = False
    current: FlowSummary | None = None
    seen_flow_names: set[str] = set()

    for raw_line in text.splitlines():
        line = raw_line.rstrip("\r")
        stripped = line.strip()
        if not stripped:
            continue

        if RETRY_SECTION_HEADER_RE.match(stripped):
            if current is not None:
                if current.name not in seen_flow_names:
                    summary.flows.append(current)
                    seen_flow_names.add(current.name)
                current = None
            break

        m = OVERALL_RE.match(stripped)
        if m:
            summary.overall = m.group(1).upper()
            continue

        m = OVERALL_LEGACY_RE.match(stripped)
        if m:
            summary.overall = m.group(1).upper()
            if m.group(2):
                summary.exit_code = int(m.group(2))
            continue

        m = ARTIFACTS_URL_RE.match(stripped)
        if m:
            summary.artifacts_url = m.group(1).strip()
            continue

        m = ARTIFACT_NAME_RE.match(stripped)
        if m:
            summary.artifact_name = m.group(1).strip()
            continue

        m = FLOW_GROUP_RE.match(stripped)
        if m:
            summary.flow_group = m.group(1).strip()
            continue

        m = FLOWS_COUNTS_RE.match(stripped)
        if m:
            summary.total = int(m.group(1))
            summary.passed = int(m.group(2))
            summary.failed = int(m.group(3))
            continue

        m = FAILED_FLOWS_RE.match(stripped)
        if m:
            summary.failed_flows = _split_csv(m.group(1))
            continue

        m = PASSED_FLOWS_RE.match(stripped)
        if m:
            summary.passed_flows = _split_csv(m.group(1))
            continue

        if PER_FLOW_HEADER_RE.match(stripped):
            in_per_flow = True
            continue

        if not in_per_flow:
            continue

        m = FLOW_LINE_RE.match(line)
        if m:
            if current is not None:
                if current.name not in seen_flow_names:
                    summary.flows.append(current)
                    seen_flow_names.add(current.name)
            current = FlowSummary(name=m.group(1).strip(), status=m.group(2).strip())
            continue

        m = INDENT_DETAIL_RE.match(line)
        if m and current is not None:
            key = m.group(1).strip()
            value = m.group(2).strip()
            if key == "failed_step":
                current.failed_step = value
            elif key == "failed_yaml_line":
                current.failed_yaml_line = value
            elif key == "error":
                current.error = value

    if current is not None and current.name not in seen_flow_names:
        summary.flows.append(current)
        seen_flow_names.add(current.name)

    if not summary.failed_flows and summary.flows:
        summary.failed_flows = [f.name for f in summary.flows if f.is_failed]
    if not summary.passed_flows and summary.flows:
        summary.passed_flows = [f.name for f in summary.flows if not f.is_failed]

    return summary


def load_maestro_ci_summary(path: Path) -> MaestroCiSummary:
    text = path.read_text(encoding="utf-8", errors="replace")
    return parse_maestro_ci_summary(text, path=path)


def discover_summaries(root: Path) -> list[MaestroCiSummary]:
    paths = sorted(root.rglob("maestro-ci-summary.txt"))
    return [load_maestro_ci_summary(path) for path in paths]
