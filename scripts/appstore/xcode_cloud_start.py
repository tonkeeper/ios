#!/usr/bin/env python3
"""Starts Xcode Cloud workflows through the App Store Connect API.

`name <workflow-id>` prints the workflow's name, which its GitHub checks carry (`<product> | <name> | <action>`).
`branch <workflow-id> <branch>` builds the branch's tip and prints the commit Xcode Cloud built, if known in 30 s; `pull-request <workflow-id> <number>...` builds each open pull
request and prints the number of each one it started; it skips with a warning one that Xcode Cloud does not know.
`commits <workflow-id>` prints the source commit of each queued or running build of the workflow: Xcode Cloud posts
a build's GitHub check only when the build leaves its queue. A start returns once its build has a source commit,
which Xcode Cloud sets a few seconds after the start, so a `commits` right after it lists the build.
The workflow needs a manual start condition of that kind.
Credentials as in `appstore_toolings.py`.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import appstore_toolings as at  # noqa: E402


def connect() -> at.AscClient:
    shared = at.release_slack(required=False)
    if shared:
        shared.load_env_file(at.repo_root() / ".env")
    key_id, issuer_id = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        raise at.UsageError("set ASC_KEY_ID and ASC_ISSUER_ID (env or the repository-root .env)")
    with at.PrivateKey() as key_path:
        return at.AscClient(at.make_jwt(key_id, issuer_id, key_path))


def start(client: at.AscClient, workflow: str, relationship: str, kind: str, source_id: str, dry_run: bool) -> str | None:
    """Returns the build's source commit, or None when Xcode Cloud has not set it in 30 s."""
    if dry_run:
        print(f"would start {workflow} on {kind} {source_id}", file=sys.stderr)
        return None
    body = {
        "data": {
            "type": "ciBuildRuns",
            "relationships": {
                "workflow": {"data": {"type": "ciWorkflows", "id": workflow}},
                relationship: {"data": {"type": kind, "id": source_id}},
            },
        }
    }
    run = client.request("POST", "/v1/ciBuildRuns", body).get("data") or {}
    number = run.get("attributes", {}).get("number")
    print(f"started build {number} on {kind} {source_id}", file=sys.stderr)
    deadline = time.monotonic() + 30
    reason = "it has no source commit after 30 s"
    while time.monotonic() < deadline:
        try:
            attributes = client.request("GET", f"/v1/ciBuildRuns/{run['id']}")["data"]["attributes"]
            sha = (attributes.get("sourceCommit") or {}).get("commitSha")
            if sha:
                return sha
            reason = "it has no source commit after 30 s"
        except Exception as error:
            reason = f"its source commit is unknown: {type(error).__name__}: {error}"
        time.sleep(2)
    print(f"::warning::build {number}: {reason}, so the next start may build its commit again", file=sys.stderr)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("kind", choices=("name", "branch", "pull-request", "commits"))
    parser.add_argument("workflow", help="Xcode Cloud workflow id")
    parser.add_argument("targets", nargs="*", help="the branch, or the pull request numbers")
    parser.add_argument("--dry-run", action="store_true", help="resolve everything, start nothing")
    args = parser.parse_args()
    try:
        client = connect()
        if args.kind == "name":
            print(client.request("GET", f"/v1/ciWorkflows/{args.workflow}")["data"]["attributes"]["name"])
            return 0
        if args.kind == "commits":
            runs = client.request("GET", f"/v1/ciWorkflows/{args.workflow}/buildRuns?limit=100&sort=-number").get("data") or []
            for run in runs:
                attributes = run["attributes"]
                sha = (attributes.get("sourceCommit") or {}).get("commitSha")
                if sha and attributes.get("executionProgress") != "COMPLETE":
                    print(sha)
            return 0
        if not args.targets:
            raise at.UsageError(f"pass the {args.kind} to build")
        repository = client.request("GET", f"/v1/ciWorkflows/{args.workflow}/repository")["data"]["id"]
        if args.kind == "branch":
            refs = client.get_all(f"/v1/scmRepositories/{repository}/gitReferences", {"limit": "200"})
            name = f"refs/heads/{args.targets[0]}"
            ref = next((r for r in refs if r["attributes"].get("canonicalName") == name and not r["attributes"].get("isDeleted")), None)
            if not ref:
                raise at.UsageError(f"Xcode Cloud does not know the branch {args.targets[0]}")
            try:
                sha = start(client, args.workflow, "sourceBranchOrTag", "scmGitReferences", ref["id"], args.dry_run)
            except OSError as error:
                print(f"error: no response, the build may have started: check App Store Connect before starting again: {error}",
                      file=sys.stderr)
                return 2
            if sha:
                print(sha)
            return 0
        pulls = client.get_all(f"/v1/scmRepositories/{repository}/pullRequests", {"limit": "200"})
        open_pulls = {p["attributes"].get("number"): p["id"] for p in pulls if not p["attributes"].get("isClosed")}
        failed = False
        for number in map(int, args.targets):
            # Xcode Cloud can miss a GitHub event: one such pull request must not fail the start of the others.
            if number not in open_pulls:
                print(f"::warning::Xcode Cloud does not know the open pull request #{number}, skipped; "
                      "close and reopen it, or push to it and get it approved again, so Xcode Cloud learns it", file=sys.stderr)
                continue
            try:
                start(client, args.workflow, "pullRequest", "scmPullRequests", open_pulls[number], args.dry_run)
            except at.AscError as error:
                print(f"error: #{number}: {error}", file=sys.stderr)
                failed = True
                continue
            except OSError as error:
                print(f"error: #{number}: no response, the build may have started: {error}", file=sys.stderr)
                failed = True
            print(number)
        return 1 if failed else 0
    except (at.UsageError, at.AscError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
