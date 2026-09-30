#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from github_artifacts import fetch_maestro_ci_artifact_urls, maestro_ci_artifact_name
from merge_attempt_summaries import (
    AutoRerunSummary,
    FinalShardStatus,
    auto_rerun_summary,
    merge_artifacts,
)
from parse_maestro_ci_summary import FlowSummary


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}
DEFAULT_CHANNEL = "tk-autotests-status"


@dataclass
class FailedFlowReport:
    flow_group: str
    flow: FlowSummary
    screenshot: Path | None
    from_rerun: bool = False


def _find_screenshot_in(root: Path, flow_name: str) -> Path | None:
    if not root.is_dir():
        return None
    stem = Path(flow_name).stem
    candidates: list[Path] = []

    search_roots = [root, root / "retry", root / "retry" / stem]
    for base in search_roots:
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            candidates.append(path)

    if not candidates:
        return None

    def rank(path: Path) -> tuple[int, float]:
        name = path.name.lower()
        text = str(path).lower()
        score = 0
        if stem.lower() in text:
            score += 4
        if "screenshot" in name or "failure" in name:
            score += 2
        if "/retry/" in text.replace("\\", "/"):
            score += 1
        return (score, path.stat().st_mtime)

    candidates.sort(key=rank, reverse=True)
    return candidates[0]


def _find_screenshot(roots: list[Path], flow_name: str) -> Path | None:
    for root in roots:
        hit = _find_screenshot_in(root, flow_name)
        if hit is not None:
            return hit
    return None


def _collect_failed_reports(statuses: list[FinalShardStatus]) -> list[FailedFlowReport]:
    reports: list[FailedFlowReport] = []
    for status in statuses:
        roots = status.screenshot_search_roots()
        rerun_present = status.rerun is not None
        for flow in status.still_failing_flows:
            reports.append(
                FailedFlowReport(
                    flow_group=status.flow_group,
                    flow=flow,
                    screenshot=_find_screenshot(roots, flow.name),
                    from_rerun=rerun_present,
                )
            )
    # Stable thread order: shard, then flow name. Screenshots used to arrive out of
    # order because text and file were separate Slack messages.
    reports.sort(key=lambda r: (r.flow_group.lower(), r.flow.name.lower()))
    return reports


def _status_emoji(passed: bool) -> str:
    return "✅" if passed else "❌"


# Cap on per-test failure thread replies, so a whole broken suite cannot flood
# the Slack thread; the overflow is summarized in a single trailing note.
MAX_UNIT_TEST_THREAD_REPLIES = 25
# Keep each reported error short enough to stay readable in a Slack thread.
MAX_UNIT_TEST_ERROR_CHARS = 1500


@dataclass
class FailedUnitTest:
    classname: str
    name: str
    errors: list[str]

    @property
    def identifier(self) -> str:
        return f"{self.classname}.{self.name}" if self.classname else self.name


def _read_unit_tests(
    unit_tests_dir: Path | None,
) -> tuple[bool | None, int, list[FailedUnitTest]]:
    """Read the maestro-unit-test-results artifact directory.

    Returns (ok, total, failed_tests): ok is None when no artifact/exit file is
    present (so the Slack line is omitted), True/False otherwise. total is the
    number of test cases in junit.xml (0 when the report is missing). failed_tests
    lists the failing test cases with their error messages, parsed from junit.xml
    when available.
    """
    if unit_tests_dir is None or not unit_tests_dir.is_dir():
        return None, 0, []
    exit_file = unit_tests_dir / "unit-tests-exit.txt"
    if not exit_file.is_file():
        return None, 0, []
    try:
        code = int(exit_file.read_text().strip() or "1")
    except ValueError:
        code = 1
    ok = code == 0
    total = 0
    failed: list[FailedUnitTest] = []
    junit = unit_tests_dir / "unit-test-reports" / "junit.xml"
    if junit.is_file():
        try:
            import xml.etree.ElementTree as ET

            root = ET.parse(junit).getroot()
            for case in root.iter("testcase"):
                total += 1
                # xcbeautify emits one <testcase> per test, with one <failure>
                # (or <error>) child per failed assertion; the reason lives in
                # the element's `message` attribute.
                nodes = case.findall("failure") + case.findall("error")
                if not nodes:
                    continue
                errors = [
                    msg
                    for node in nodes
                    if (msg := (node.get("message") or node.text or "").strip())
                ]
                failed.append(
                    FailedUnitTest(
                        classname=case.get("classname", ""),
                        name=case.get("name", ""),
                        errors=errors,
                    )
                )
        except Exception as exc:  # noqa: BLE001 - report-only, never fail Slack
            print(f"slack: could not parse unit junit.xml: {exc}", file=sys.stderr)

    # xcbeautify's JUnit collapses parallel swift-testing failures into a single
    # generic "Parallel test failed". The unit-test runner recovers the real
    # per-assertion text from the xcresult into unit-test-failures.json; prefer
    # it as the source of failing tests + messages when present.
    failures_json = unit_tests_dir / "unit-test-reports" / "unit-test-failures.json"
    if failures_json.is_file():
        try:
            import json

            entries = json.loads(failures_json.read_text())
        except Exception as exc:  # noqa: BLE001 - report-only, never fail Slack
            print(f"slack: could not parse unit-test-failures.json: {exc}", file=sys.stderr)
            entries = []
        if entries:
            rich: list[FailedUnitTest] = []
            for entry in entries:
                identifier = entry.get("identifier") or entry.get("name") or ""
                parts = identifier.split("/")
                rich.append(
                    FailedUnitTest(
                        classname="/".join(parts[:-1]),
                        name=parts[-1] if parts else identifier,
                        errors=[m for m in (entry.get("messages") or []) if m],
                    )
                )
            failed = rich
            total = max(total, len(failed))
    return ok, total, failed


def _unit_tests_line(
    unit_tests_ok: bool | None,
    unit_tests_total: int,
    failed_unit_tests: list[FailedUnitTest],
) -> str | None:
    """Unit-test status block, or None when no unit-test artifact was found.

    A bold "*Unit tests:*" header followed by one summary line:
      passing -> "N tests passed ✅"
      failing -> "K / N unit tests failed ❌ (details in thread)"
    The per-test breakdown lives in the thread, not the root message.
    """
    if unit_tests_ok is None:
        return None
    header = "*Unit tests:*"
    if unit_tests_ok:
        count = f"{unit_tests_total} tests" if unit_tests_total > 0 else "tests"
        return f"{header}\n{count} passed {_status_emoji(True)}"
    failed_count = len(failed_unit_tests)
    if failed_count > 0 and unit_tests_total > 0:
        body = (
            f"{failed_count} / {unit_tests_total} unit tests failed "
            f"{_status_emoji(False)} (details in thread)"
        )
    elif failed_count > 0:
        body = f"{failed_count} unit tests failed {_status_emoji(False)} (details in thread)"
    else:
        # Non-zero exit with no per-test failures parsed (e.g. a build/run
        # failure) -> no thread replies to point at.
        body = f"unit tests failed {_status_emoji(False)}"
    return f"{header}\n{body}"


def _shard_line(
    status: FinalShardStatus,
    urls: dict[str, str],
    run_id: str,
) -> str:
    group = status.flow_group
    line = (
        f"• `{group}` {_status_emoji(status.is_passed)} "
        f"({status.final_passed}/{status.total})"
    )
    if status.rerun is not None:
        line += " (auto-rerun)"
    artifact_url = urls.get(group) or status.first_attempt.artifacts_url
    artifact_label = (
        status.first_attempt.artifact_name
        or (maestro_ci_artifact_name(run_id, group) if run_id else None)
        or "logs & screenshots"
    )
    if artifact_url:
        line += f" — <{artifact_url}|{artifact_label}>"
    return line


def _cluster_block(
    title: str,
    statuses: list[FinalShardStatus],
    urls: dict[str, str],
    run_id: str,
) -> list[str]:
    total = sum(s.total for s in statuses)
    passed = sum(s.final_passed for s in statuses)
    failed = sum(s.final_failed for s in statuses)
    all_ok = failed == 0 and all(s.is_passed for s in statuses)
    if all_ok:
        emoji = "✅"
        summary = "all green"
    else:
        emoji = "❌"
        summary = f"{failed} failed"
    lines = [
        f"{emoji} *{title}* — {summary} · "
        f"{total} total | {passed} passed | {failed} failed  (gates pipeline)"
    ]
    lines.extend(_shard_line(s, urls, run_id) for s in statuses)
    return lines


def _build_main_text(
    *,
    platform: str,
    statuses: list[FinalShardStatus],
    rerun: AutoRerunSummary,
    run_url: str,
    build_ok: bool,
    artifact_urls: dict[str, str] | None = None,
    run_id: str = "",
    unit_tests_ok: bool | None = None,
    unit_tests_total: int = 0,
    failed_unit_tests: list[FailedUnitTest] | None = None,
) -> str:
    unit_line = _unit_tests_line(unit_tests_ok, unit_tests_total, failed_unit_tests or [])

    if not statuses:
        if not build_ok:
            parts = [f"{_status_emoji(False)} *{platform} Maestro UI tests* — build failed"]
            if unit_line:
                parts.append(unit_line)
            parts.append(f"<{run_url}|Open workflow run>")
            return "\n".join(parts)
        parts = [f"{_status_emoji(False)} *{platform} Maestro UI tests* — no test summaries found"]
        if unit_line:
            parts.append(unit_line)
        parts.append(f"<{run_url}|Open workflow run>")
        return "\n".join(parts)

    urls = artifact_urls or {}

    lines = [f"*{platform} Maestro UI tests*"]
    if rerun.ran:
        recovered = len(rerun.recovered_flows)
        retried = recovered + len(rerun.still_failing_flows)
        lines.append(
            f"auto-rerun: {recovered}/{retried} recovered "
            f"across {len(rerun.shards)} shard(s)"
        )

    lines.append("")
    lines.extend(_cluster_block("multichain", statuses, urls, run_id))

    if unit_line:
        lines.append("")
        lines.append(unit_line)
    lines.append("")
    lines.append(f"<{run_url}|Open workflow run>")
    return "\n".join(lines)


def _build_rerun_thread_text(rerun: AutoRerunSummary) -> str:
    if not rerun.ran:
        return ""
    lines: list[str] = [
        f"🔁 *auto-rerun* — shards: {', '.join(sorted(set(rerun.shards)))}"
    ]
    if rerun.recovered_flows:
        recovered_lines = [f"`{shard}/{flow}`" for shard, flow in rerun.recovered_flows]
        lines.append(f"recovered ({len(rerun.recovered_flows)}): " + ", ".join(recovered_lines))
    else:
        lines.append("recovered: none")
    if rerun.still_failing_flows:
        still_lines = [f"`{shard}/{flow}`" for shard, flow in rerun.still_failing_flows]
        lines.append(
            f"still failing ({len(rerun.still_failing_flows)}): " + ", ".join(still_lines)
        )
    else:
        lines.append("still failing: none (all retried flows recovered)")
    return "\n".join(lines)


def _build_thread_text(report: FailedFlowReport) -> str:
    """One Slack thread reply body: failed test + step/line + error (+ no-screenshot note)."""
    flow = report.flow
    header = f"*Failed test:* `{flow.name}` (`{report.flow_group}`)"
    if report.from_rerun:
        header += " — _still failing after auto-rerun_"
    lines = [header]
    if flow.failed_step:
        lines.append(f"*Step:* `{flow.failed_step}`")
    if flow.failed_yaml_line:
        lines.append(f"*YAML line:* `{flow.failed_yaml_line}`")
    if flow.error:
        lines.append(f"*Error:* {flow.error}")
    elif not flow.failed_step and not flow.failed_yaml_line:
        lines.append("*Error:* _no error details in summary_")
    if report.screenshot is None:
        lines.append("_no failure screenshot in artifacts_")
    return "\n".join(lines)


def _build_unit_test_thread_text(test: FailedUnitTest) -> str:
    header = (
        f"🧪 *{test.name}* (`{test.classname}`)"
        if test.classname
        else f"🧪 *{test.name}*"
    )
    lines = [header]
    if test.errors:
        for err in test.errors:
            if len(err) > MAX_UNIT_TEST_ERROR_CHARS:
                err = err[:MAX_UNIT_TEST_ERROR_CHARS] + " …(truncated)"
            lines.append(f"error: {err}")
    else:
        lines.append("_no error message in the JUnit report_")
    return "\n".join(lines)


class SlackClient:
    _RETRYABLE_STATUS = {429, 500, 502, 503, 504}
    _RETRYABLE_SLACK_ERRORS = {
        "ratelimited",
        "service_unavailable",
        "internal_error",
        "fatal_error",
    }
    _CHANNEL_ID_RE = re.compile(r"^[CGDZ][A-Z0-9]{8,}$")

    def __init__(
        self,
        token: str,
        channel: str,
        *,
        dry_run: bool = False,
        max_attempts: int = 4,
        base_backoff: float = 1.5,
    ) -> None:
        self.token = token
        self.channel = channel.lstrip("#")
        self.dry_run = dry_run
        self.max_attempts = max(1, max_attempts)
        self.base_backoff = max(0.1, base_backoff)
        self.channel_id: str | None = (
            self.channel if self._CHANNEL_ID_RE.match(self.channel) else None
        )

    def _sleep_for(self, attempt: int, *, retry_after: float | None = None) -> None:
        if retry_after is not None and retry_after > 0:
            delay = min(retry_after, 60.0)
        else:
            jitter = random.uniform(0.0, 0.4)
            delay = self.base_backoff * (2 ** attempt) + jitter
        time.sleep(delay)

    @staticmethod
    def _retry_after_seconds(headers: object) -> float | None:
        try:
            value = headers.get("Retry-After") if headers else None
        except AttributeError:
            return None
        if not value:
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    def _execute(
        self,
        req: urllib.request.Request,
        *,
        timeout: float,
        op_name: str,
    ) -> dict:
        last_err: Exception | None = None
        for attempt in range(self.max_attempts):
            try:
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    raw = resp.read()
                try:
                    body = json.loads(raw.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                    raise RuntimeError(
                        f"Slack {op_name}: non-JSON response: {exc}"
                    ) from exc
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode("utf-8", errors="replace")
                if exc.code in self._RETRYABLE_STATUS and attempt + 1 < self.max_attempts:
                    last_err = RuntimeError(
                        f"Slack {op_name}: HTTP {exc.code}: {detail}"
                    )
                    print(
                        f"slack: {op_name} HTTP {exc.code}; retry "
                        f"{attempt + 1}/{self.max_attempts - 1}",
                        file=sys.stderr,
                    )
                    self._sleep_for(attempt, retry_after=self._retry_after_seconds(exc.headers))
                    continue
                raise RuntimeError(
                    f"Slack {op_name}: HTTP {exc.code}: {detail}"
                ) from exc
            except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as exc:
                if attempt + 1 < self.max_attempts:
                    last_err = exc
                    print(
                        f"slack: {op_name} network error ({exc}); retry "
                        f"{attempt + 1}/{self.max_attempts - 1}",
                        file=sys.stderr,
                    )
                    self._sleep_for(attempt)
                    continue
                raise RuntimeError(f"Slack {op_name}: {exc}") from exc

            if body.get("ok"):
                return body

            err = str(body.get("error") or "unknown_error")
            retry_after = body.get("response_metadata", {}).get("retry_after") if isinstance(
                body.get("response_metadata"), dict
            ) else None
            try:
                retry_after_float = float(retry_after) if retry_after is not None else None
            except (TypeError, ValueError):
                retry_after_float = None
            if err in self._RETRYABLE_SLACK_ERRORS and attempt + 1 < self.max_attempts:
                last_err = RuntimeError(f"Slack {op_name}: {err}")
                print(
                    f"slack: {op_name} returned {err!r}; retry "
                    f"{attempt + 1}/{self.max_attempts - 1}",
                    file=sys.stderr,
                )
                self._sleep_for(attempt, retry_after=retry_after_float)
                continue
            raise RuntimeError(f"Slack {op_name}: {err} (full response: {body})")

        raise RuntimeError(
            f"Slack {op_name}: exhausted retries ({self.max_attempts}); last error: {last_err}"
        )

    def _request_json(self, url: str, payload: dict, *, op_name: str) -> dict:
        if self.dry_run:
            print(f"[dry-run] POST {url}\n{json.dumps(payload, ensure_ascii=False, indent=2)}")
            return {"ok": True, "ts": "dry-run-ts", "file_id": "dry-run-file", "upload_url": "dry-run-url"}
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json; charset=utf-8",
            },
            method="POST",
        )
        return self._execute(req, timeout=60.0, op_name=op_name)

    def _request_form(self, url: str, params: dict[str, str], *, op_name: str) -> dict:
        if self.dry_run:
            print(f"[dry-run] FORM {url}\n{params}")
            return {"ok": True, "upload_url": "dry-run-url", "file_id": "dry-run-file"}
        data = urllib.parse.urlencode(params).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
            },
            method="POST",
        )
        return self._execute(req, timeout=60.0, op_name=op_name)

    def post_message(self, text: str, *, thread_ts: str | None = None) -> str:
        payload: dict[str, object] = {
            "channel": self.channel,
            "text": text,
            "unfurl_links": False,
            "unfurl_media": False,
        }
        if thread_ts:
            payload["thread_ts"] = thread_ts
        body = self._request_json(
            "https://slack.com/api/chat.postMessage",
            payload,
            op_name="chat.postMessage",
        )
        resolved_channel = str(body.get("channel") or "")
        if resolved_channel and self._CHANNEL_ID_RE.match(resolved_channel):
            self.channel_id = resolved_channel
        return str(body.get("ts", ""))

    def try_post_message(self, text: str, *, thread_ts: str | None = None) -> str | None:
        try:
            return self.post_message(text, thread_ts=thread_ts)
        except Exception as exc:
            print(f"slack: try_post_message swallowed: {exc}", file=sys.stderr)
            return None

    def upload_file(
        self,
        path: Path,
        *,
        thread_ts: str,
        title: str,
        initial_comment: str | None = None,
    ) -> None:
        if self.dry_run:
            print(
                f"[dry-run] upload {path} to thread {thread_ts}"
                + (f" comment={initial_comment!r}" if initial_comment else "")
            )
            return

        channel_id = self._resolve_channel_id()

        size = path.stat().st_size
        get_url = self._request_form(
            "https://slack.com/api/files.getUploadURLExternal",
            {"filename": path.name, "length": str(size)},
            op_name="files.getUploadURLExternal",
        )
        upload_url = str(get_url.get("upload_url") or "")
        file_id = str(get_url.get("file_id") or "")
        if not upload_url or not file_id:
            raise RuntimeError(
                f"files.getUploadURLExternal: missing upload_url/file_id (got {get_url})"
            )

        self._upload_bytes(upload_url, path, op_name="files.uploadExternal")

        complete_payload: dict[str, object] = {
            "files": [{"id": file_id, "title": title}],
            "channel_id": channel_id,
            "thread_ts": thread_ts,
        }
        if initial_comment:
            complete_payload["initial_comment"] = initial_comment
        self._request_json(
            "https://slack.com/api/files.completeUploadExternal",
            complete_payload,
            op_name="files.completeUploadExternal",
        )

    def _resolve_channel_id(self) -> str:
        if self.channel_id and self._CHANNEL_ID_RE.match(self.channel_id):
            return self.channel_id
        cursor = ""
        for _ in range(20):
            params = {
                "limit": "1000",
                "exclude_archived": "true",
                "types": "public_channel,private_channel",
            }
            if cursor:
                params["cursor"] = cursor
            body = self._request_form(
                "https://slack.com/api/conversations.list",
                params,
                op_name="conversations.list",
            )
            for ch in body.get("channels", []) or []:
                if not isinstance(ch, dict):
                    continue
                if ch.get("name") == self.channel:
                    cid = str(ch.get("id") or "")
                    if self._CHANNEL_ID_RE.match(cid):
                        self.channel_id = cid
                        return cid
            cursor = str(
                (body.get("response_metadata") or {}).get("next_cursor") or ""
            )
            if not cursor:
                break
        raise RuntimeError(
            f"Slack: could not resolve channel id for {self.channel!r}; "
            "either pass --channel as a channel ID (e.g. 'C012345ABC') or "
            "post a main message first so the ID can be captured from chat.postMessage."
        )

    def _upload_bytes(self, upload_url: str, path: Path, *, op_name: str) -> None:
        file_bytes = path.read_bytes()
        boundary = "----MaestroSlackBoundary"
        prefix = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
            "Content-Type: application/octet-stream\r\n\r\n"
        ).encode("utf-8")
        suffix = f"\r\n--{boundary}--\r\n".encode("utf-8")
        body = prefix + file_bytes + suffix

        last_err: Exception | None = None
        for attempt in range(self.max_attempts):
            req = urllib.request.Request(
                upload_url,
                data=body,
                headers={
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                },
                method="POST",
            )
            try:
                with urllib.request.urlopen(req, timeout=120) as resp:
                    resp.read()
                return
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode("utf-8", errors="replace")
                if exc.code in self._RETRYABLE_STATUS and attempt + 1 < self.max_attempts:
                    last_err = RuntimeError(f"Slack {op_name}: HTTP {exc.code}: {detail}")
                    self._sleep_for(attempt, retry_after=self._retry_after_seconds(exc.headers))
                    continue
                raise RuntimeError(f"Slack {op_name}: HTTP {exc.code}: {detail}") from exc
            except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as exc:
                if attempt + 1 < self.max_attempts:
                    last_err = exc
                    self._sleep_for(attempt)
                    continue
                raise RuntimeError(f"Slack {op_name}: {exc}") from exc
        raise RuntimeError(
            f"Slack {op_name}: exhausted retries ({self.max_attempts}); last error: {last_err}"
        )


def _post_failed_flow_report(
    slack: SlackClient,
    report: FailedFlowReport,
    thread_ts: str,
) -> None:
    # One Slack message per failure: caption (test + error) + screenshot together.
    # Separate chat.postMessage + files.completeUploadExternal races in the thread
    # (file shares land later), so screenshots used to appear under the wrong test.
    comment = _build_thread_text(report)
    screenshot = report.screenshot
    if screenshot is not None and screenshot.is_file():
        try:
            slack.upload_file(
                screenshot,
                thread_ts=thread_ts,
                title=f"{report.flow.name} failure",
                initial_comment=comment,
            )
            return
        except Exception as exc:
            print(
                f"slack: screenshot upload failed for {report.flow.name}: {exc}",
                file=sys.stderr,
            )
            slack.post_message(comment, thread_ts=thread_ts)
            slack.try_post_message(
                f"_screenshot upload failed for `{report.flow.name}`: {exc}_",
                thread_ts=thread_ts,
            )
            return

    slack.post_message(comment, thread_ts=thread_ts)


def _post_failed_unit_tests(
    slack: SlackClient,
    failed_unit_tests: list[FailedUnitTest],
    thread_ts: str,
) -> None:
    """Post one thread reply per failed unit test (capped), like UI flows."""
    if not failed_unit_tests:
        return
    capped = failed_unit_tests[:MAX_UNIT_TEST_THREAD_REPLIES]
    posted = 0
    for test in capped:
        if (
            slack.try_post_message(
                _build_unit_test_thread_text(test), thread_ts=thread_ts
            )
            is not None
        ):
            posted += 1
    overflow = len(failed_unit_tests) - len(capped)
    if overflow > 0:
        slack.try_post_message(
            f"_…and {overflow} more failed unit test(s); see the workflow run_",
            thread_ts=thread_ts,
        )
    print(
        f"slack: posted {posted}/{len(capped)} failed unit-test report(s)"
        + (f"; {overflow} not shown" if overflow else ""),
        file=sys.stderr,
    )


def post_maestro_slack_status(
    *,
    artifacts_dir: Path,
    run_url: str,
    slack: SlackClient,
    platform: str = "iOS",
    build_ok: bool = True,
    artifact_urls: dict[str, str] | None = None,
    run_id: str = "",
    unit_tests_ok: bool | None = None,
    unit_tests_total: int = 0,
    failed_unit_tests: list[FailedUnitTest] | None = None,
) -> int:
    failed_unit_tests = failed_unit_tests or []
    statuses = merge_artifacts(artifacts_dir)
    rerun = auto_rerun_summary(statuses)
    main_text = _build_main_text(
        platform=platform,
        statuses=statuses,
        rerun=rerun,
        run_url=run_url,
        build_ok=build_ok,
        artifact_urls=artifact_urls,
        run_id=run_id,
        unit_tests_ok=unit_tests_ok,
        unit_tests_total=unit_tests_total,
        failed_unit_tests=failed_unit_tests,
    )
    thread_ts = slack.post_message(main_text)

    if rerun.ran:
        slack.try_post_message(_build_rerun_thread_text(rerun), thread_ts=thread_ts)

    failed_reports = _collect_failed_reports(statuses)
    posted = 0
    failed_to_post = 0
    for report in failed_reports:
        try:
            _post_failed_flow_report(slack, report, thread_ts)
            posted += 1
        except Exception as exc:
            failed_to_post += 1
            print(
                f"slack: failed to post thread reply for {report.flow.name}: {exc}",
                file=sys.stderr,
            )
            slack.try_post_message(
                f"_failed to post details for `{report.flow.name}`: {exc}_",
                thread_ts=thread_ts,
            )

    if failed_to_post:
        slack.try_post_message(
            f"_note: {failed_to_post} flow report(s) could not be posted; "
            f"see workflow logs for details_",
            thread_ts=thread_ts,
        )
    print(
        f"slack: posted {posted} failed-flow report(s); "
        f"{failed_to_post} could not be posted",
        file=sys.stderr,
    )

    _post_failed_unit_tests(slack, failed_unit_tests, thread_ts)

    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts-dir", type=Path, required=True)
    ap.add_argument("--run-url", required=True)
    ap.add_argument("--platform", default="iOS")
    ap.add_argument("--channel", default=os.environ.get("SLACK_CHANNEL", DEFAULT_CHANNEL))
    ap.add_argument("--token", default=os.environ.get("SLACK_BOT_TOKEN", ""))
    ap.add_argument(
        "--build-ok",
        default=os.environ.get("MAESTRO_BUILD_OK", "true"),
    )
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID", ""))
    ap.add_argument(
        "--github-repository",
        default=os.environ.get("GITHUB_REPOSITORY", ""),
    )
    ap.add_argument(
        "--github-token",
        default=os.environ.get("GITHUB_TOKEN", ""),
    )
    ap.add_argument(
        "--github-server-url",
        default=os.environ.get("GITHUB_SERVER_URL", "https://github.com"),
    )
    ap.add_argument(
        "--unit-tests-dir",
        type=Path,
        default=None,
        help="Path to the downloaded maestro-unit-test-results artifact directory.",
    )
    args = ap.parse_args()

    if not args.token and not args.dry_run:
        print("post_maestro_slack_status: set SLACK_BOT_TOKEN or pass --token", file=sys.stderr)
        return 2

    build_ok = str(args.build_ok).lower() in {"1", "true", "yes", "on"}
    unit_tests_ok, unit_tests_total, failed_unit_tests = _read_unit_tests(args.unit_tests_dir)
    slack = SlackClient(args.token, args.channel, dry_run=args.dry_run)

    artifact_urls: dict[str, str] | None = None
    if args.run_id and args.github_repository and args.github_token:
        try:
            artifact_urls = fetch_maestro_ci_artifact_urls(
                repository=args.github_repository,
                run_id=args.run_id,
                token=args.github_token,
                server_url=args.github_server_url,
            )
        except RuntimeError as exc:
            print(f"post_maestro_slack_status: artifact URL lookup failed: {exc}", file=sys.stderr)
    elif not args.dry_run:
        print(
            "post_maestro_slack_status: GITHUB_RUN_ID/GITHUB_REPOSITORY/GITHUB_TOKEN missing; "
            "shard links will omit artifact downloads",
            file=sys.stderr,
        )

    return post_maestro_slack_status(
        artifacts_dir=args.artifacts_dir,
        run_url=args.run_url,
        slack=slack,
        platform=args.platform,
        build_ok=build_ok,
        artifact_urls=artifact_urls,
        run_id=args.run_id,
        unit_tests_ok=unit_tests_ok,
        unit_tests_total=unit_tests_total,
        failed_unit_tests=failed_unit_tests,
    )


if __name__ == "__main__":
    raise SystemExit(main())
