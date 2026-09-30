from __future__ import annotations

import time
import unittest

import maestro_log_parse

from maestro_log_parse import (
    RUN_FLOW_RE,
    STEP_FAILED_RE,
    STEP_STATUS_RE,
    main_flow_failed_step_index,
    match_run_flow,
    match_step_failed,
    match_step_status,
    split_by_flows,
)


_RUNNER = "maestro.cli.runner.MaestroCommandRunner.runCommands"
# A `runFlow` command line as maestro --verbose emits it: the whole CommandMetadata payload
# lands on one line, which is why the retry log's median line length is ~12 KB.
_BULKY_LINE = (
    f"06:05:23.267 [ INFO] {_RUNNER}$lambda$11: "
    "Run ../../../steps/import_wallet.yaml metadata CommandMetadata("
    + "sourceDescription=steps/import_wallet.yaml, " * 300
    + ")"
)

_LINES = [
    _BULKY_LINE,
    "06:05:20.001 [ INFO] maestro.cli.runner.TestSuiteInteractor - Running flow send_ton",
    "06:05:20.002 [ INFO] maestro.cli.runner.TestRunner.runSingle: Running flow send_ton.yaml...",
    f"06:05:21.100 [ INFO] {_RUNNER}$lambda$4: Assert that \"Existing Wallet\" is visible FAILED",
    f"06:05:21.101 [ INFO] {_RUNNER}$lambda$0: Tap on \"Send\" RUNNING",
    "06:05:21.102 [ INFO] maestro.cli.runner.CliConsoleListener.onCommandFinished: Tap on \"Send\" COMPLETED",
    "06:05:21.103 [ INFO] maestro.cli.runner.TestSuiteInteractor - Assert visible FAILED",
    "06:05:21.104 [ERROR] [Command execution] CommandFailed: element not found",
    "",
    "not a maestro line at all",
]


class StepStatusPatternTests(unittest.TestCase):
    def test_current_cli_runner_step_lines_are_parsed(self) -> None:
        """MaestroCommandRunner is what the CLI logs today; only the older loggers were listed."""
        m = match_step_failed(
            f'06:06:06.698 [ INFO] {_RUNNER}$lambda$4: Assert that "Existing Wallet" is visible FAILED'
        )
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), 'Assert that "Existing Wallet" is visible')

        m = match_step_status(f"06:05:15.168 [ INFO] {_RUNNER}$lambda$0: Define variables RUNNING")
        self.assertEqual((m.group(1), m.group(2)), ("Define variables", "RUNNING"))

    def test_legacy_logger_layouts_still_parse(self) -> None:
        m = match_step_status(
            "06:05:21.102 [ INFO] maestro.cli.runner.CliConsoleListener.onCommandFinished: Tap on X COMPLETED"
        )
        self.assertEqual((m.group(1), m.group(2)), ("Tap on X", "COMPLETED"))
        m = match_step_failed(
            "06:05:21.103 [ INFO] maestro.cli.runner.TestSuiteInteractor - Assert visible FAILED"
        )
        self.assertEqual(m.group(1), "Assert visible")

    def test_command_metadata_dump_is_not_a_step_line(self) -> None:
        self.assertIsNone(match_step_status(_BULKY_LINE))
        self.assertIsNone(match_step_failed(_BULKY_LINE))

    def test_failed_step_is_attributed_to_the_top_level_command(self) -> None:
        lines = [
            f"06:05:15.168 [ INFO] {_RUNNER}$lambda$0: Launch app RUNNING",
            f"06:05:15.175 [ INFO] {_RUNNER}$lambda$2: Launch app COMPLETED",
            f"06:05:23.250 [ INFO] {_RUNNER}$lambda$0: Run ../../../steps/import_wallet.yaml RUNNING",
            _BULKY_LINE,
            f"06:05:31.731 [ INFO] {_RUNNER}$lambda$0: Assert that \"X\" is visible RUNNING",
            f"06:06:06.698 [ INFO] {_RUNNER}$lambda$4: Assert that \"X\" is visible FAILED",
            f"06:06:06.937 [ INFO] {_RUNNER}$lambda$4: Run ../../../steps/import_wallet.yaml FAILED",
        ]
        self.assertEqual(main_flow_failed_step_index(lines), 1)


class GuardedMatchersTests(unittest.TestCase):
    """The prechecks must be transparent: same matches, without the backtracking."""

    def test_guards_agree_with_raw_patterns(self) -> None:
        for line in _LINES:
            with self.subTest(line=line[:60]):
                for guarded, pattern in (
                    (match_run_flow, RUN_FLOW_RE),
                    (match_step_failed, STEP_FAILED_RE),
                    (match_step_status, STEP_STATUS_RE),
                ):
                    expected = pattern.search(line)
                    actual = guarded(line)
                    self.assertEqual(actual is None, expected is None)
                    if expected is not None:
                        self.assertEqual(actual.groups(), expected.groups())

    def test_bulky_log_parses_without_quadratic_backtracking(self) -> None:
        lines = [
            "06:05:20.001 [ INFO] maestro.cli.runner.TestRunner.runSingle: Running flow send_ton.yaml..."
        ] + [_BULKY_LINE] * 200
        started = time.perf_counter()
        flows = split_by_flows(lines)
        elapsed = time.perf_counter() - started

        self.assertEqual([flow.name for flow in flows], ["send_ton"])
        # Unguarded this is ~60s; the bound is loose enough to survive a slow CI runner.
        self.assertLess(elapsed, 5.0, f"split_by_flows took {elapsed:.1f}s")



class RetryBlockTests(unittest.TestCase):
    PREFIX = "16:30:00.000 [ INFO] maestro.cli.runner.CliConsoleListener.onCommandFinished: "
    START = "16:30:00.000 [ INFO] maestro.cli.runner.CliConsoleListener.onCommandStart: "

    def _flow(self, retry_status: str, tail: list[str]) -> list[str]:
        return [
            "16:29:00.000 [ INFO] maestro.cli.runner.TestSuiteInteractor.runFlow:  Running flow hide_show",
            self.START + "Tap on BTC RUNNING",
            self.PREFIX + "Tap on BTC COMPLETED",
            self.START + "Retry 5 times RUNNING",
            self.START + 'Assert that "Hide in Wallet" is visible RUNNING',
            self.PREFIX + 'Assert that "Hide in Wallet" is visible FAILED',
            self.START + 'Assert that "Hide in Wallet" is visible RUNNING',
            self.PREFIX + 'Assert that "Hide in Wallet" is visible ' + ("COMPLETED" if retry_status == "COMPLETED" else "FAILED"),
            self.PREFIX + "Retry 5 times " + retry_status,
        ] + tail

    def test_failed_attempt_inside_a_completed_retry_is_not_a_flow_failure(self) -> None:
        lines = self._flow("COMPLETED", [self.START + "Tap on Hide RUNNING", self.PREFIX + "Tap on Hide COMPLETED"])
        self.assertEqual(maestro_log_parse.failed_flow_names(lines), [])
        self.assertIsNone(maestro_log_parse.main_flow_failed_step_index(lines))

    def test_exhausted_retry_fails_the_flow_at_the_retry_command(self) -> None:
        lines = self._flow("FAILED", [])
        self.assertEqual(maestro_log_parse.failed_flow_names(lines), ["hide_show"])
        # Tap on BTC is command 0, the retry block is command 1.
        self.assertEqual(maestro_log_parse.main_flow_failed_step_index(lines), 1)

if __name__ == "__main__":
    unittest.main()
