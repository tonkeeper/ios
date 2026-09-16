from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from merge_attempt_summaries import auto_rerun_summary, merge_artifacts


def _summary(flow_group: str, flows: list[tuple[str, str]], *, error: str = "boom") -> str:
    failed = sum(1 for _, status in flows if status == "FAILED")
    lines = [
        "=== Maestro CI summary ===",
        f"flow_group: {flow_group}",
        f"overall: {'FAILED' if failed else 'PASSED'}",
        f"flows: {len(flows)} total | {len(flows) - failed} passed | {failed} failed",
        "",
        "Per flow:",
    ]
    for name, status in flows:
        lines.append(f"  {name}: {status}")
        if status == "FAILED":
            lines.append(f"    error: {error}")
    return "\n".join(lines) + "\n"


class MergeAttemptSummariesTests(unittest.TestCase):
    def test_rerun_summary_is_authoritative_over_raw_retry_log(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            first_dir = root / "first-attempt" / "maestro-ci-1-transactions"
            rerun_dir = root / "rerun" / "maestro-ci-rerun-1-transactions"
            first_dir.mkdir(parents=True)
            rerun_dir.mkdir(parents=True)

            (first_dir / "maestro-ci-summary.txt").write_text(
                """=== Maestro CI summary ===
flow_group: transactions
overall: FAILED
flows: 2 total | 0 passed | 2 failed

Per flow:
  recovered_flow: FAILED
    error: first attempt failed
  failing_flow: FAILED
    error: first attempt failed
"""
            )
            (rerun_dir / "maestro-ci-summary.txt").write_text(
                """=== Maestro CI summary ===
flow_group: transactions
overall: FAILED
flows: 2 total | 1 passed | 1 failed

Per flow:
  recovered_flow: PASSED
  failing_flow: FAILED
    error: rerun failed
"""
            )
            (rerun_dir / "maestro-retry.log").write_text(
                """===== RETRY: /tmp/recovered_flow.yaml (exit 1) =====
===== RETRY: /tmp/failing_flow.yaml (exit 0) =====
"""
            )

            statuses = merge_artifacts(root)
            rerun = auto_rerun_summary(statuses)

            self.assertEqual(
                rerun.recovered_flows,
                [("transactions", "recovered_flow")],
            )
            self.assertEqual(
                rerun.still_failing_flows,
                [("transactions", "failing_flow")],
            )
            self.assertEqual(statuses[0].still_failing_flows[0].error, "rerun failed")


class InShardRetryTests(unittest.TestCase):
    """The shard retries its own failed YAMLs; what it recovered never reaches the auto-rerun."""

    def _build(self, temp_dir: str, *, rerun: list[tuple[str, str]] | None) -> Path:
        root = Path(temp_dir)
        first = root / "first-attempt" / "maestro-ci-1-transactions"
        first.mkdir(parents=True)
        (first / "maestro-ci-summary.txt").write_text(
            _summary("transactions", [("recovered_in_shard", "FAILED"), ("hard_fail", "FAILED")])
        )
        (first / "maestro-ci-summary-retry.txt").write_text(
            _summary("transactions", [("recovered_in_shard", "PASSED"), ("hard_fail", "FAILED")])
        )
        if rerun is not None:
            rerun_dir = root / "rerun" / "maestro-ci-rerun-1-transactions"
            rerun_dir.mkdir(parents=True)
            (rerun_dir / "maestro-ci-summary.txt").write_text(_summary("transactions", rerun))
        return root

    def test_in_shard_recovery_is_not_reported_as_still_failing(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = self._build(temp_dir, rerun=[("hard_fail", "FAILED")])
            (status,) = merge_artifacts(root)

            self.assertEqual([f.name for f in status.still_failing_flows], ["hard_fail"])
            self.assertEqual(status.final_failed, 1)
            self.assertEqual(
                auto_rerun_summary([status]).still_failing_flows,
                [("transactions", "hard_fail")],
            )

    def test_in_shard_recovery_without_auto_rerun(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = self._build(temp_dir, rerun=None)
            (status,) = merge_artifacts(root)

            self.assertEqual([f.name for f in status.still_failing_flows], ["hard_fail"])

    def test_flow_the_auto_rerun_never_ran_stays_failing(self) -> None:
        """Only an in-shard pass clears a first-attempt failure; a skipped flow still failed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            first = root / "first-attempt" / "maestro-ci-1-transactions"
            rerun = root / "rerun" / "maestro-ci-rerun-1-transactions"
            first.mkdir(parents=True)
            rerun.mkdir(parents=True)
            (first / "maestro-ci-summary.txt").write_text(
                _summary("transactions", [("skipped_by_rerun", "FAILED"), ("hard_fail", "FAILED")])
            )
            (rerun / "maestro-ci-summary.txt").write_text(
                _summary("transactions", [("hard_fail", "FAILED")])
            )
            (status,) = merge_artifacts(root)

            self.assertEqual(
                sorted(f.name for f in status.still_failing_flows),
                ["hard_fail", "skipped_by_rerun"],
            )


if __name__ == "__main__":
    unittest.main()
