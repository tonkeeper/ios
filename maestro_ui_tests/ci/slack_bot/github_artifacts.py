#!/usr/bin/env python3
"""Resolve Maestro CI artifact download URLs from a GitHub Actions workflow run."""

from __future__ import annotations

import json
import urllib.error
import urllib.request


def maestro_ci_artifact_name(run_id: str, flow_group: str) -> str:
    return f"maestro-ci-{run_id}-{flow_group}"


def fetch_maestro_ci_artifact_urls(
    *,
    repository: str,
    run_id: str,
    token: str,
    server_url: str = "https://github.com",
) -> dict[str, str]:
    """
    Return flow_group -> browser URL for artifacts uploaded by
    "Upload Maestro log and screen recording" (name maestro-ci-<run_id>-<flow_group>).
    """
    if "/" not in repository:
        raise ValueError(f"repository must be owner/name, got {repository!r}")

    owner, repo = repository.split("/", 1)
    api_url = (
        f"https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/artifacts?per_page=100"
    )
    req = urllib.request.Request(
        api_url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API HTTP {exc.code}: {detail}") from exc

    prefix = f"maestro-ci-{run_id}-"
    urls: dict[str, str] = {}
    for artifact in payload.get("artifacts", []):
        name = str(artifact.get("name", ""))
        if not name.startswith(prefix):
            continue
        flow_group = name[len(prefix) :]
        if not flow_group:
            continue
        artifact_id = artifact.get("id")
        if artifact_id is None:
            continue
        urls[flow_group] = (
            f"{server_url.rstrip('/')}/{owner}/{repo}/actions/runs/{run_id}/artifacts/{artifact_id}"
        )
    return urls


def flow_group_from_artifact_name(name: str, run_id: str) -> str | None:
    """Extract flow_group from maestro-ci-<run_id>-<flow_group> or None."""
    prefix = f"maestro-ci-{run_id}-"
    if not name.startswith(prefix):
        return None
    group = name[len(prefix) :]
    return group or None
