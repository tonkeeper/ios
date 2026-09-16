#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from parse_maestro_ci_summary import (
    FlowSummary,
    MaestroCiSummary,
    discover_summaries,
    load_maestro_ci_summary,
)

FIRST_ATTEMPT_SUBDIR = "first-attempt"
RERUN_SUBDIR = "rerun"
# Written by write_maestro_shard_summary.sh next to the first-attempt summary: the shard's
# own retry of its failed YAMLs. Flows it recovered never reach the auto-rerun job, so
# without it their first-pass failure would be read as "still failing".
IN_SHARD_RETRY_SUMMARY_NAME = "maestro-ci-summary-retry.txt"


def _merge_failure_details(
    primary: FlowSummary, fallback: FlowSummary | None
) -> FlowSummary:
    """Prefer primary status/error, but keep first-attempt step/line when rerun omitted them."""
    if fallback is None:
        return primary
    return FlowSummary(
        name=primary.name,
        status=primary.status,
        failed_step=primary.failed_step or fallback.failed_step,
        failed_yaml_line=primary.failed_yaml_line or fallback.failed_yaml_line,
        error=primary.error or fallback.error,
    )


@dataclass
class FinalShardStatus:
    flow_group: str
    first_attempt: MaestroCiSummary
    rerun: MaestroCiSummary | None = None
    in_shard_retry: MaestroCiSummary | None = None

    @property
    def total(self) -> int:
        return self.first_attempt.total or len(self.first_attempt.flows)

    @property
    def _in_shard_recovered(self) -> set[str]:
        if self.in_shard_retry is None:
            return set()
        return {flow.name for flow in self.in_shard_retry.flows if not flow.is_failed}

    def _first_failed_unique(self) -> list[FlowSummary]:
        recovered = self._in_shard_recovered
        seen: set[str] = set()
        out: list[FlowSummary] = []
        for flow in self.first_attempt.flows:
            if not flow.is_failed:
                continue
            if flow.name in recovered or flow.name in seen:
                continue
            seen.add(flow.name)
            out.append(flow)
        return out

    @property
    def recovered_flows(self) -> list[str]:
        if self.rerun is None:
            return []
        first_failed = {flow.name for flow in self._first_failed_unique()}
        recovered: list[str] = []
        for flow in self.rerun.flows:
            if flow.name in first_failed and not flow.is_failed:
                recovered.append(flow.name)
        return recovered

    @property
    def still_failing_flows(self) -> list[FlowSummary]:
        if self.rerun is None:
            return self._first_failed_unique()

        rerun_by_name = {flow.name: flow for flow in self.rerun.flows}
        first_failed = self._first_failed_unique()
        result = []
        seen: set[str] = set()
        for first_flow in first_failed:
            seen.add(first_flow.name)
            rerun_flow = rerun_by_name.get(first_flow.name)
            if rerun_flow is None:
                result.append(first_flow)
            elif rerun_flow.is_failed:
                result.append(_merge_failure_details(rerun_flow, first_flow))
        for flow in self.rerun.flows:
            if flow.is_failed and flow.name not in seen:
                result.append(flow)
                seen.add(flow.name)
        return result

    @property
    def final_failed(self) -> int:
        return len(self.still_failing_flows)

    @property
    def final_passed(self) -> int:
        total = self.total
        if not total:
            return 0
        return max(0, total - self.final_failed)

    @property
    def is_passed(self) -> bool:
        return self.final_failed == 0

    @property
    def screenshot_root(self) -> Path:
        if self.rerun is not None:
            return self.rerun.path.parent
        return self.first_attempt.path.parent

    def screenshot_search_roots(self) -> list[Path]:
        roots: list[Path] = []
        if self.rerun is not None:
            roots.append(self.rerun.path.parent)
        roots.append(self.first_attempt.path.parent)
        return roots


def _summaries_in(root: Path) -> list[MaestroCiSummary]:
    if not root.is_dir():
        return []
    return [
        load_maestro_ci_summary(p)
        for p in sorted(root.rglob("maestro-ci-summary.txt"))
    ]


def discover_first_summaries(root: Path) -> list[MaestroCiSummary]:
    first_dir = root / FIRST_ATTEMPT_SUBDIR
    if first_dir.is_dir():
        return _summaries_in(first_dir)
    rerun_dir = root / RERUN_SUBDIR
    if rerun_dir.is_dir():
        return []
    return discover_summaries(root)


def discover_rerun_summaries(root: Path) -> list[MaestroCiSummary]:
    rerun_dir = root / RERUN_SUBDIR
    if rerun_dir.is_dir():
        return _summaries_in(rerun_dir)
    return []


def _shard_key(summary: MaestroCiSummary) -> str:
    return (summary.flow_group or summary.path.parent.name).strip()


def _in_shard_retry_summary(first: MaestroCiSummary) -> MaestroCiSummary | None:
    path = first.path.parent / IN_SHARD_RETRY_SUMMARY_NAME
    return load_maestro_ci_summary(path) if path.is_file() else None


def merge_artifacts(root: Path) -> list[FinalShardStatus]:
    first_summaries = discover_first_summaries(root)
    rerun_summaries = discover_rerun_summaries(root)
    rerun_by_shard: dict[str, MaestroCiSummary] = {}
    for summary in rerun_summaries:
        rerun_by_shard[_shard_key(summary)] = summary

    final: list[FinalShardStatus] = []
    seen: set[str] = set()
    for summary in first_summaries:
        key = _shard_key(summary)
        if key in seen:
            continue
        seen.add(key)
        rerun_summary = rerun_by_shard.get(key)
        final.append(
            FinalShardStatus(
                flow_group=key,
                first_attempt=summary,
                rerun=rerun_summary,
                in_shard_retry=_in_shard_retry_summary(summary),
            )
        )
    final.sort(key=lambda s: s.flow_group)
    return final


@dataclass
class AutoRerunSummary:
    shards: list[str] = field(default_factory=list)
    recovered_flows: list[tuple[str, str]] = field(default_factory=list)
    still_failing_flows: list[tuple[str, str]] = field(default_factory=list)

    @property
    def ran(self) -> bool:
        return bool(self.shards)


def auto_rerun_summary(statuses: list[FinalShardStatus]) -> AutoRerunSummary:
    out = AutoRerunSummary()
    for status in statuses:
        if status.rerun is None:
            continue
        out.shards.append(status.flow_group)
        for flow in status.recovered_flows:
            out.recovered_flows.append((status.flow_group, flow))
        for flow in status.still_failing_flows:
            out.still_failing_flows.append((status.flow_group, flow.name))
    return out
