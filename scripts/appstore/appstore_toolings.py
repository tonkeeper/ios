#!/usr/bin/env python3
"""App Store Connect release tooling for the iOS app: release info, then release by the version's state.

Each release needs the same clicks-through in App Store Connect: pick the processed build for the version
and its release options (manual or automatic release, phased 7-day rollout), type the release notes per
locale, send the version to review, release it once approved, and pause, resume or complete the rollout.
`make appstore_toolings` does them from the terminal (a numbered chooser, or `ACTION=info|release|status`
to skip it): `info` sets the build, release options and What's New; `release` does the one step the
version's state allows (submit, publish, or pause / resume / complete the rollout) and, when it publishes,
tags the tip of `release/ios/<version>` as `ios/<version>_<build>` and pushes the tag (`--commit` names another
commit; a tip newer than the build's upload is refused); `status` posts the
version's state to Slack ("waiting for review", "1%" ... "100%"; `SLACK_BOT_TOKEN` and
`SLACK_RELEASES_CHANNEL`, through `shared/scripts/release_slack.py`, which Android's `playstore_toolings`
shares; the public mirror does not carry it, so there `status` is unavailable and `.env` is not read).
The release notes go through a PR (`scripts/appstore/whats_new.txt`) and the steps are repeatable.

The script only works with a version that already exists in App Store Connect (it offers to create a
missing one) and never creates locales. It is stdlib-only on purpose — macOS ships Python 3.9 without
PyJWT or `cryptography` — so the ES256 token is signed by shelling out to `openssl`.

Credentials (env or the gitignored `.env` at the repository root): `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
`ASC_PRIVATE_KEY_PATH` (an `AuthKey_<id>.p8`) or `ASC_PRIVATE_KEY_BASE64`. The key needs the App Manager
role to edit version metadata and submit.
"""

from __future__ import annotations

import argparse
import base64
import datetime
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

ASC_BASE_URL = "https://api.appstoreconnect.apple.com"
DEFAULT_BUNDLE_ID = "com.jbig.tonkeeper"
DEFAULT_SECTION = "default"
# App Store Connect rejects a longer "What's New"; checked before any request so a bad file costs no writes.
MAX_WHATS_NEW = 4000
# States in which App Store Connect still accepts metadata edits. Anything else is rejected with a 409, but
# a readable message beats decoding one.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "WAITING_FOR_REVIEW",
    "INVALID_BINARY",
}
# How many of the newest builds of the version are considered; the chooser lists the attachable ones.
MAX_BUILDS = 10
# A review submission in one of these states blocks creating another one for the same platform.
OPEN_SUBMISSION_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}
SECTION_RE = re.compile(r"^\[([A-Za-z][A-Za-z0-9-]*)\]\s*$")
VERSION_RE = re.compile(r"^APP_VERSION_COMMON\s*=\s*(\d{2}\.\d{2}\.\d+)", re.MULTILINE)
VERSION_STRING_RE = re.compile(r"^\d{2}\.\d{2}\.\d+$")

ACTIONS = (
    ("info", "Manage release info (build, release type, phased rollout, What's New)"),
    ("release", "Manage release (submit to review, publish, phased rollout)"),
    ("status", "Post the release status to Slack (waiting for review / N%)"),
)
# Apple's phased release schedule: share of users with automatic updates per day.
PHASED_PERCENT_BY_DAY = {1: 1, 2: 2, 3: 5, 4: 10, 5: 20, 6: 50, 7: 100}
# `release` action: states that need no action, and states in which the phased rollout can be managed.
# READY_FOR_REVIEW is not one of them: the version sits in a review submission nobody has sent yet.
IN_REVIEW_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW"}
RELEASED_STATES = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE"}
RELEASE_TYPES = {"manual": "MANUAL", "auto": "AFTER_APPROVAL"}
RELEASE_TYPE_LABELS = {"MANUAL": "manual", "AFTER_APPROVAL": "after approval", "SCHEDULED": "scheduled"}
# `rollout` action: the transitions App Store Connect allows from each phased release state.
ROLLOUT_TRANSITIONS = {
    "ACTIVE": (("pause", "Pause the rollout", "PAUSED"), ("complete", "Release to everyone now", "COMPLETE")),
    "PAUSED": (("resume", "Resume the rollout", "ACTIVE"), ("complete", "Release to everyone now", "COMPLETE")),
}
# Publishing tags the shipped commit: the tip of the platform release branch, named like Android's
# `android/<version>_<code>` tags from .github/workflows/publish.yml.
GIT_REMOTE = "origin"
RELEASE_BRANCH = "release/ios/{version}"
RELEASE_TAG = "ios/{version}_{build}"


class UsageError(Exception):
    """A problem the user can fix: bad file, missing credentials, no such version."""


# ---------------------------------------------------------------------------------------------------
# Paths, environment, terminal


def ios_root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]


def repo_root() -> pathlib.Path:
    return ios_root().parent


def release_slack(required: bool = True):
    """The shared `.env` / Slack module, imported on demand: the public mirror has no `shared/scripts/`.

    Without `required` a missing module answers `None` instead of raising."""
    directory = repo_root() / "shared" / "scripts"
    if not (directory / "release_slack.py").is_file():
        if not required:
            return None
        raise UsageError("shared/scripts/release_slack.py is not in this checkout; ACTION=status needs the private monorepo")
    if str(directory) not in sys.path:
        sys.path.insert(0, str(directory))
    import release_slack  # noqa: PLC0415

    return release_slack


def default_version() -> str | None:
    config = ios_root() / "Configurations" / "common.xcconfig"
    if not config.is_file():
        return None
    match = VERSION_RE.search(config.read_text(encoding="utf-8"))
    return match.group(1) if match else None


def interactive() -> bool:
    return sys.stdin.isatty()


def confirm(question: str) -> bool:
    """Asks on a terminal; answers no when there is none (CI), so nothing is created or submitted blindly."""
    if not interactive():
        return False
    try:
        answer = input(f"{question} [y/N] ")
    except EOFError:
        return False
    return answer.strip().lower() in ("y", "yes")


def ask(question: str, default: str) -> str:
    """Free-text answer with a default; the default wins without a terminal."""
    if not interactive():
        return default
    try:
        answer = input(f"{question} [{default}] ").strip()
    except EOFError:
        return default
    return answer or default


def next_version(current: str, now: time.struct_time | None = None) -> str:
    """The rule of scripts/bump_version.sh: bump N within the same month, else YY.MM.0."""
    yy, mm, n = current.split(".")
    now = now or time.localtime()
    cur_yy, cur_mm = f"{now.tm_year % 100:02d}", f"{now.tm_mon:02d}"
    if (cur_yy, cur_mm) == (yy, mm):
        return f"{yy}.{mm}.{int(n) + 1}"
    return f"{cur_yy}.{cur_mm}.0"


def choose(title: str, options: list[str], default: int = 0) -> int:
    """Numbered chooser; returns the index. Without a terminal the default wins."""
    print(title)
    for number, option in enumerate(options, start=1):
        print(f"  {number}. {option}")
    if not interactive():
        return default
    count = len(options)
    while True:
        try:
            raw = input(f"Choose [1-{count}] (default {default + 1}): ").strip()
        except EOFError:
            return default
        if not raw:
            return default
        if raw.isdigit() and 1 <= int(raw) <= count:
            return int(raw) - 1
        print("not an option")


# ---------------------------------------------------------------------------------------------------
# Notes file


def parse_notes(text: str) -> dict[str, str]:
    """`[locale]` headers start sections; `#` lines before the first header are comments.

    Keys are lower-cased so `[en-us]` and `[en-US]` both match App Store Connect's `en-US`.
    """
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line_number, line in enumerate(text.splitlines(), start=1):
        header = SECTION_RE.match(line)
        if header:
            key = header.group(1).lower()
            if key in sections:
                raise UsageError(f"line {line_number}: duplicate section [{header.group(1)}]")
            sections[key] = []
            current = key
            continue
        if current is None:
            if line.strip() and not line.lstrip().startswith("#"):
                raise UsageError(f"line {line_number}: text before the first [locale] section")
            continue
        sections[current].append(line.rstrip())

    if not sections:
        raise UsageError("the notes file has no [locale] sections")

    notes: dict[str, str] = {}
    for key, lines in sections.items():
        body = "\n".join(lines).strip("\n")
        if not body.strip():
            raise UsageError(f"section [{key}] is empty")
        if len(body) > MAX_WHATS_NEW:
            raise UsageError(f"section [{key}] is {len(body)} characters; App Store Connect allows {MAX_WHATS_NEW}")
        notes[key] = body
    return notes


# ---------------------------------------------------------------------------------------------------
# ES256 JWT via openssl


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_to_raw_signature(der: bytes, size: int = 32) -> bytes:
    """ECDSA DER `SEQUENCE { INTEGER r, INTEGER s }` → fixed-size `r || s`, as JOSE wants it."""

    def read_length(buf: bytes, pos: int) -> tuple[int, int]:
        first = buf[pos]
        if first < 0x80:
            return first, pos + 1
        count = first & 0x7F
        return int.from_bytes(buf[pos + 1 : pos + 1 + count], "big"), pos + 1 + count

    if not der or der[0] != 0x30:
        raise ValueError("signature is not a DER SEQUENCE")
    _, pos = read_length(der, 1)
    parts = []
    for _ in range(2):
        if der[pos] != 0x02:
            raise ValueError("signature component is not a DER INTEGER")
        length, pos = read_length(der, pos + 1)
        value = int.from_bytes(der[pos : pos + length], "big")
        pos += length
        parts.append(value.to_bytes(size, "big"))
    return b"".join(parts)


def sign_es256(private_key_path: pathlib.Path, signing_input: bytes) -> bytes:
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(private_key_path)],
        input=signing_input,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise UsageError(f"openssl could not sign with {private_key_path}: {result.stderr.decode().strip()}")
    return der_to_raw_signature(result.stdout)


def make_jwt(key_id: str, issuer_id: str, private_key_path: pathlib.Path) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer_id, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"}
    encode = lambda obj: b64url(json.dumps(obj, separators=(",", ":")).encode())  # noqa: E731
    signing_input = f"{encode(header)}.{encode(claims)}".encode("ascii")
    signature = sign_es256(private_key_path, signing_input)
    return f"{signing_input.decode('ascii')}.{b64url(signature)}"


class PrivateKey:
    """Resolves `ASC_PRIVATE_KEY_PATH` or materialises `ASC_PRIVATE_KEY_BASE64` into a 0600 temp file."""

    def __init__(self) -> None:
        self._temp: pathlib.Path | None = None
        self.path: pathlib.Path

    def __enter__(self) -> pathlib.Path:
        key_path = os.environ.get("ASC_PRIVATE_KEY_PATH")
        key_b64 = os.environ.get("ASC_PRIVATE_KEY_BASE64")
        if key_path:
            self.path = pathlib.Path(key_path).expanduser()
            if not self.path.is_file():
                raise UsageError(f"ASC_PRIVATE_KEY_PATH does not exist: {self.path}")
        elif key_b64:
            fd, name = tempfile.mkstemp(prefix="asc_key_", suffix=".p8")
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "wb") as handle:
                handle.write(base64.b64decode(key_b64))
            self._temp = self.path = pathlib.Path(name)
        else:
            raise UsageError("set ASC_PRIVATE_KEY_PATH (path to AuthKey_<id>.p8) or ASC_PRIVATE_KEY_BASE64")
        return self.path

    def __exit__(self, *_: object) -> None:
        if self._temp:
            self._temp.unlink(missing_ok=True)


# ---------------------------------------------------------------------------------------------------
# App Store Connect client


class AscError(Exception):
    pass


class AscClient:
    VERSION_FIELDS = {"fields[appStoreVersions]": "versionString,appVersionState,platform,releaseType"}
    BUILD_FIELDS = {"fields[builds]": "version,uploadedDate,processingState,usesNonExemptEncryption,expired,buildAudienceType"}
    PHASED_FIELDS = {"fields[appStoreVersionPhasedReleases]": "phasedReleaseState,startDate,currentDayNumber"}

    def __init__(self, token: str) -> None:
        self._token = token

    def request(self, method: str, path_or_url: str, body: dict | None = None, allow_404: bool = False) -> dict:
        url = path_or_url if path_or_url.startswith("http") else ASC_BASE_URL + path_or_url
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self._token}")
        request.add_header("Accept", "application/json")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
        except urllib.error.HTTPError as error:
            if allow_404 and error.code == 404:
                return {}
            raise AscError(self._describe(error, method, url)) from None
        except urllib.error.URLError as error:
            raise AscError(f"{method} {url}: {error.reason}") from None
        return json.loads(payload) if payload else {}

    @staticmethod
    def _describe(error: urllib.error.HTTPError, method: str, url: str) -> str:
        try:
            errors = json.loads(error.read()).get("errors", [])
            details = "; ".join(f"{e.get('title', '')}: {e.get('detail', '')}".strip(": ") for e in errors)
        except (ValueError, AttributeError):
            details = ""
        hint = ""
        if error.code == 401:
            hint = " (check ASC_KEY_ID / ASC_ISSUER_ID / the .p8 file)"
        elif error.code == 403:
            hint = " (the API key needs the App Manager role)"
        return f"{method} {url} -> HTTP {error.code}{hint}: {details or error.reason}"

    def get_all(self, path: str, params: dict[str, str] | None = None) -> list[dict]:
        url = path + ("?" + urllib.parse.urlencode(params) if params else "")
        items: list[dict] = []
        while url:
            page = self.request("GET", url)
            items.extend(page.get("data", []))
            url = page.get("links", {}).get("next")
        return items

    # Apps and versions

    def app_id(self, bundle_id: str) -> str:
        # `filter[bundleId]` is a prefix match, so `com.jbig.tonkeeper` also returns `.dev` and `UK`.
        apps = self.get_all("/v1/apps", {"filter[bundleId]": bundle_id, "fields[apps]": "bundleId"})
        exact = [app for app in apps if app["attributes"]["bundleId"] == bundle_id]
        if len(exact) != 1:
            found = ", ".join(app["attributes"]["bundleId"] for app in apps) or "none"
            raise UsageError(f"expected one app with bundle id {bundle_id}; found: {found}")
        return exact[0]["id"]

    def app_store_version(self, app_id: str, version: str) -> dict | None:
        versions = self.get_all(
            f"/v1/apps/{app_id}/appStoreVersions",
            {"filter[platform]": "IOS", "filter[versionString]": version, **self.VERSION_FIELDS},
        )
        return versions[0] if versions else None

    def editable_versions(self, app_id: str) -> list[str]:
        return [
            v["attributes"]["versionString"]
            for v in self.get_all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS", **self.VERSION_FIELDS})
            if v["attributes"].get("appVersionState") in EDITABLE_STATES
        ]

    def create_app_store_version(self, app_id: str, version: str) -> dict:
        return self.request(
            "POST",
            "/v1/appStoreVersions",
            {
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {"platform": "IOS", "versionString": version},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )["data"]

    def set_release_type(self, version_id: str, release_type: str) -> None:
        self.request(
            "PATCH",
            f"/v1/appStoreVersions/{version_id}",
            {"data": {"type": "appStoreVersions", "id": version_id, "attributes": {"releaseType": release_type}}},
        )

    def release_version(self, version_id: str) -> None:
        self.request(
            "POST",
            "/v1/appStoreVersionReleaseRequests",
            {
                "data": {
                    "type": "appStoreVersionReleaseRequests",
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
                }
            },
        )

    # Phased release

    def phased_release(self, version_id: str) -> dict | None:
        # A version without a phased release answers `data: null`; 404 is tolerated for the same meaning.
        return self.request(
            "GET",
            f"/v1/appStoreVersions/{version_id}/appStoreVersionPhasedRelease?" + urllib.parse.urlencode(self.PHASED_FIELDS),
            allow_404=True,
        ).get("data")

    def create_phased_release(self, version_id: str) -> None:
        self.request(
            "POST",
            "/v1/appStoreVersionPhasedReleases",
            {
                "data": {
                    "type": "appStoreVersionPhasedReleases",
                    "attributes": {"phasedReleaseState": "INACTIVE"},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
                }
            },
        )

    def delete_phased_release(self, phased_id: str) -> None:
        self.request("DELETE", f"/v1/appStoreVersionPhasedReleases/{phased_id}")

    def set_phased_release_state(self, phased_id: str, state: str) -> None:
        self.request(
            "PATCH",
            f"/v1/appStoreVersionPhasedReleases/{phased_id}",
            {"data": {"type": "appStoreVersionPhasedReleases", "id": phased_id, "attributes": {"phasedReleaseState": state}}},
        )

    # Localizations

    def localizations(self, version_id: str) -> list[dict]:
        return self.get_all(
            f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
            {"fields[appStoreVersionLocalizations]": "locale,whatsNew", "limit": "200"},
        )

    def set_whats_new(self, localization_id: str, text: str) -> None:
        self.request(
            "PATCH",
            f"/v1/appStoreVersionLocalizations/{localization_id}",
            {"data": {"type": "appStoreVersionLocalizations", "id": localization_id, "attributes": {"whatsNew": text}}},
        )

    # Builds

    def builds(self, app_id: str, version: str, limit: int = MAX_BUILDS) -> list[dict]:
        """Newest builds of the version, like App Store Connect's "Add Build" sheet, with the App Store
        version each one is already attached to (`attachedTo`, a `versionString`) so the chooser can say why
        a build is greyed out there."""
        page = self.request(
            "GET",
            "/v1/builds?"
            + urllib.parse.urlencode(
                {
                    "filter[app]": app_id,
                    "filter[preReleaseVersion.version]": version,
                    "sort": "-uploadedDate",
                    "limit": str(limit),
                    "include": "appStoreVersion",
                    "fields[appStoreVersions]": "versionString,appVersionState",
                    **self.BUILD_FIELDS,
                }
            ),
        )
        versions = {v["id"]: v["attributes"] for v in page.get("included", []) if v.get("type") == "appStoreVersions"}
        builds = page.get("data", [])
        for build in builds:
            linked = (build.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")
            build["attachedTo"] = versions.get(linked, {}).get("versionString") if linked else None
        return builds

    def attached_build(self, version_id: str) -> dict | None:
        return self.request("GET", f"/v1/appStoreVersions/{version_id}/build?" + urllib.parse.urlencode(self.BUILD_FIELDS)).get("data")

    def attach_build(self, version_id: str, build_id: str) -> None:
        self.request(
            "PATCH",
            f"/v1/appStoreVersions/{version_id}/relationships/build",
            {"data": {"type": "builds", "id": build_id}},
        )

    def set_encryption_exempt(self, build_id: str) -> None:
        self.request(
            "PATCH",
            f"/v1/builds/{build_id}",
            {"data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}},
        )

    # Review submissions

    def open_submissions(self, app_id: str) -> list[dict]:
        return [
            s
            for s in self.get_all(
                "/v1/reviewSubmissions",
                {"filter[app]": app_id, "filter[platform]": "IOS", "fields[reviewSubmissions]": "state,platform"},
            )
            if s["attributes"].get("state") in OPEN_SUBMISSION_STATES
        ]

    def create_submission(self, app_id: str) -> str:
        return self.request(
            "POST",
            "/v1/reviewSubmissions",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )["data"]["id"]

    def add_submission_item(self, submission_id: str, version_id: str) -> None:
        self.request(
            "POST",
            "/v1/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )

    def submit(self, submission_id: str) -> None:
        self.request(
            "PATCH",
            f"/v1/reviewSubmissions/{submission_id}",
            {"data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}},
        )


# ---------------------------------------------------------------------------------------------------
# Release tag


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=repo_root(), capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise UsageError(f"git {' '.join(args)}: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout.strip()


def release_branch(version: str) -> str:
    return RELEASE_BRANCH.format(version=version)


def release_tag(version: str, build: str) -> str:
    return RELEASE_TAG.format(version=version, build=build)


def release_commit(version: str) -> str:
    """The tip of the release branch on the remote, fetched so it can be tagged locally."""
    branch = release_branch(version)
    try:
        git("fetch", "--quiet", GIT_REMOTE, f"refs/heads/{branch}")
    except UsageError as error:
        raise UsageError(f"no branch {branch} on {GIT_REMOTE} to tag ({error})") from None
    return git("rev-parse", "--verify", "FETCH_HEAD^{commit}")


def resolve_commit(revision: str) -> str:
    """A commit named by the operator (`--commit`), taken as is: it is not checked against the branch."""
    try:
        return git("rev-parse", "--verify", "--quiet", f"{revision}^{{commit}}")
    except UsageError:
        raise UsageError(f"{revision} is not a commit in this checkout; fetch it first") from None


def committer_date(commit: str) -> str:
    return git("show", "-s", "--format=%cI", commit)


def parse_iso(value: str) -> datetime.datetime:
    """ISO 8601 with an offset, as git `%cI` and App Store Connect's `uploadedDate` give it (`Z` tolerated)."""
    return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))


def local_time(value: str | None) -> str:
    """`YYYY-MM-DD HH:MM` in this machine's timezone; empty when the value is missing."""
    if not value:
        return ""
    return parse_iso(value).astimezone().strftime("%Y-%m-%d %H:%M")


def tip_after_upload(committed: str, uploaded: str | None) -> bool:
    """Whether the branch tip was committed after the build was uploaded, i.e. the build cannot contain it."""
    if not uploaded:
        return False
    return parse_iso(committed) > parse_iso(uploaded)


def remote_tag(tag: str) -> str | None:
    """The commit the tag points at on the remote, else `None`."""
    found = git("ls-remote", "--tags", GIT_REMOTE, f"refs/tags/{tag}")
    return found.split()[0] if found else None


def local_tag(tag: str) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{tag}^{{commit}}"],
        cwd=repo_root(),
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def tag_decision(tag: str, remote: str | None, local: str | None, commit: str) -> str:
    """`tag` when the remote lacks the tag, `skip` when it already marks the commit there.

    Only the remote counts as published; a local tag on the commit is just reused by `push_tag`. A tag on
    another commit, remote or local, is an error so it is found before the release, not after."""
    if remote == commit:
        return "skip"
    if remote is not None:
        raise UsageError(f"tag {tag} on {GIT_REMOTE} points at {remote[:7]}, not at {commit[:7]}; move it by hand or fix the branch")
    if local is not None and local != commit:
        raise UsageError(f"local tag {tag} points at {local[:7]}, not at {commit[:7]}; delete it (git tag -d {tag}) or fix the branch")
    return "tag"


def push_tag(tag: str, commit: str) -> None:
    if local_tag(tag) != commit:
        git("tag", tag, commit)
    git("push", GIT_REMOTE, f"refs/tags/{tag}")


# ---------------------------------------------------------------------------------------------------
# Shared steps


class Context:
    def __init__(self, client: AscClient, args: argparse.Namespace, version: str) -> None:
        self.client = client
        self.args = args
        self.version = version
        self.app_id = client.app_id(args.bundle_id)

    def resolve_version(self, allow_create: bool) -> dict | None:
        """The App Store version, created after a prompt when missing. `None` means a dry run stopped."""
        client, args = self.client, self.args
        asc_version = client.app_store_version(self.app_id, self.version)
        if asc_version is None:
            editable = ", ".join(client.editable_versions(self.app_id)) or "none"
            print(f"no iOS App Store version {self.version} for {args.bundle_id} (editable versions: {editable})")
            if not allow_create:
                raise UsageError("create the version first (action 1 offers to)")
            if not args.create and not confirm(f"Create App Store version {self.version}?"):
                raise UsageError("version not created; pass --create (make CREATE=1) to create it without asking")
            if args.dry_run:
                print(f"dry run: would create App Store version {self.version}")
                return None
            asc_version = client.create_app_store_version(self.app_id, self.version)
            print(f"created App Store version {self.version}")
        state = asc_version["attributes"].get("appVersionState")
        print(f"{args.bundle_id} {self.version} ({state})")
        if state not in EDITABLE_STATES:
            if not allow_create:
                raise UsageError(f"version {self.version} is in state {state}; it can no longer be edited")
            return self.prepare_next_version(state)
        return asc_version

    def prepare_next_version(self, state: str) -> dict | None:
        """Switches to the next version (an editable one if any, else the bump rule) and creates it on demand."""
        client, args = self.client, self.args
        editable = client.editable_versions(self.app_id)
        candidate = editable[0] if editable else next_version(self.version)
        print(f"version {self.version} is {state}; editable versions: {', '.join(editable) or 'none'}")
        # Only the version taken from common.xcconfig is replaced, and only after asking: an explicit
        # --version names what the operator wants, and --create means "create it", not "pick another".
        if args.version or not interactive():
            raise UsageError(
                f"version {self.version} can no longer be edited; pass --version {candidate} "
                f"(make VERSION={candidate}; CREATE=1 creates it) to prepare the next version"
            )
        chosen = ask("Prepare version", candidate)
        if not VERSION_STRING_RE.match(chosen):
            raise UsageError(f"{chosen} is not a YY.MM.N version")
        self.version = chosen
        asc_version = client.app_store_version(self.app_id, chosen)
        if asc_version is not None:
            chosen_state = asc_version["attributes"].get("appVersionState")
            print(f"{args.bundle_id} {chosen} ({chosen_state})")
            if chosen_state not in EDITABLE_STATES:
                raise UsageError(f"version {chosen} is in state {chosen_state}; it can no longer be edited")
        if chosen != default_version():
            print(
                f"note: Configurations/common.xcconfig still has {default_version()}; run scripts/bump_version.sh "
                f"so the next build carries {chosen}"
            )
        if asc_version is not None:
            return asc_version
        if args.dry_run:
            print(f"dry run: would create App Store version {chosen}")
            return None
        asc_version = client.create_app_store_version(self.app_id, chosen)
        print(f"created App Store version {chosen}")
        return asc_version


def describe_build(build: dict) -> str:
    attrs = build["attributes"]
    uploaded = local_time(attrs.get("uploadedDate"))
    compliance = {None: "missing compliance", True: "uses non-exempt encryption", False: "encryption exempt"}
    return f"build {attrs.get('version')}  {uploaded}  {compliance[attrs.get('usesNonExemptEncryption')]}"


def build_blocker(build: dict, version: str) -> str | None:
    """Why App Store Connect would grey the build out in its picker, or `None` when it can be attached."""
    attrs = build["attributes"]
    if attrs.get("expired"):
        return "expired"
    if attrs.get("processingState") != "VALID":
        return (attrs.get("processingState") or "unknown state").lower()
    # Xcode Cloud's "TestFlight (Internal Testing Only)" uploads are INTERNAL_ONLY; App Store Connect
    # greys them out in its picker because they can never ship to the App Store.
    if attrs.get("buildAudienceType") == "INTERNAL_ONLY":
        return "TestFlight internal testing only"
    if build.get("attachedTo") and build["attachedTo"] != version:
        return f"attached to version {build['attachedTo']}"
    return None


def describe_phased_release(phased: dict | None) -> str:
    if phased is None:
        return "everyone at once"
    attrs = phased["attributes"]
    state = (attrs.get("phasedReleaseState") or "unknown").lower()
    if state == "inactive":
        return "phased over 7 days (not started)"
    parts = [f"phased over 7 days, {state}"]
    if attrs.get("currentDayNumber"):
        parts.append(f"day {attrs['currentDayNumber']} of 7")
    if attrs.get("startDate"):
        parts.append(f"started {attrs['startDate'][:10]}")
    return ", ".join(parts)


def describe_release_options(release_type: str | None, phased: dict | None) -> str:
    label = RELEASE_TYPE_LABELS.get(release_type or "", release_type or "unknown")
    return f"release: {label}, rollout: {describe_phased_release(phased)}"


def plan_release_options(
    current_type: str | None, phased_enabled: bool, wanted_type: str | None, wanted_phased: bool | None
) -> list[str]:
    """Steps that bring the version's release options to the wanted ones; `None` means keep."""
    plan = []
    if wanted_type and wanted_type != current_type:
        plan.append(f"set release type to {RELEASE_TYPE_LABELS[wanted_type]}")
    if wanted_phased is not None and wanted_phased != phased_enabled:
        plan.append("enable phased release" if wanted_phased else "disable phased release")
    return plan


def rollout_transitions(state: str | None) -> tuple[tuple[str, str, str], ...]:
    """`(key, label, target state)` triples the `rollout` action offers from the current phased state."""
    return ROLLOUT_TRANSITIONS.get(state or "", ())


def status_label(version_attrs: dict, phased: dict | None) -> str | None:
    """The Slack status line, or `None` when the state is not one the team announces."""
    state = version_attrs.get("appVersionState")
    if state in IN_REVIEW_STATES:
        return "waiting for review"
    if state not in RELEASED_STATES:
        return None
    if phased and phased["attributes"].get("phasedReleaseState") in ("ACTIVE", "PAUSED"):
        day = phased["attributes"].get("currentDayNumber") or 1
        return f"{PHASED_PERCENT_BY_DAY.get(day, 100)}%"
    return "100%"


# ---------------------------------------------------------------------------------------------------
# Action 1: manage release info (build, release options, What's New)


def step_build(ctx: Context, asc_version: dict) -> bool:
    """Attaches the chosen build and sets the release options; `False` when no build could be attached."""
    client, args = ctx.client, ctx.args

    current = client.attached_build(asc_version["id"])
    if current:
        print(f"attached: {describe_build(current)}")

    builds = client.builds(ctx.app_id, ctx.version)
    blockers = {b["id"]: build_blocker(b, ctx.version) for b in builds}
    valid = [b for b in builds if blockers[b["id"]] is None]
    chosen = None
    if args.build:
        chosen = next((b for b in builds if b["attributes"].get("version") == args.build), None)
        if chosen is None:
            raise UsageError(f"build {args.build} is not a build of {ctx.version}")
        if blockers[chosen["id"]]:
            raise UsageError(f"build {args.build} cannot be attached: {blockers[chosen['id']]}")
    elif valid:
        chosen = valid[choose(f"Attachable builds of {ctx.version}, newest first:", [describe_build(b) for b in valid])]
    else:
        states = ", ".join(f"{b['attributes'].get('version')} ({blockers[b['id']]})" for b in builds) or "none"
        print(
            f"warning: no attachable build for {ctx.version} (builds: {states}); upload one or wait for processing",
            file=sys.stderr,
        )

    attach = chosen is not None and (not current or current["id"] != chosen["id"])
    # Export compliance is a legal declaration, so it has its own consent: the prompt or --encryption-exempt.
    # --create only covers creating the version.
    declare_exempt = False
    if chosen and chosen["attributes"].get("usesNonExemptEncryption") is None:
        declare_exempt = args.encryption_exempt or confirm(
            "The build has no export compliance. Declare it uses only exempt encryption?"
        )
        if not declare_exempt:
            print(
                "warning: export compliance stays missing; App Review will not accept the build "
                "(pass --encryption-exempt / make ENCRYPTION_EXEMPT=1 to declare it without asking)",
                file=sys.stderr,
            )

    # Release options: a flag, else the chooser (defaulting to the current setting); without a terminal
    # and without a flag they stay as App Store Connect has them.
    current_type = asc_version["attributes"].get("releaseType")
    phased = client.phased_release(asc_version["id"])
    print(describe_release_options(current_type, phased))
    wanted_type = wanted_phased = None
    if args.release:
        wanted_type = RELEASE_TYPES[args.release]
    elif current_type == "SCHEDULED":
        print("release type stays scheduled; pass --release manual|auto (make RELEASE=...) to change it")
    elif interactive():
        index = choose(
            "Release this version:",
            ["Manually (make appstore_toolings ACTION=release)", "Automatically after approval"],
            default=1 if current_type == "AFTER_APPROVAL" else 0,
        )
        wanted_type = ("MANUAL", "AFTER_APPROVAL")[index]
    if args.phased_release:
        wanted_phased = args.phased_release == "on"
    elif interactive():
        options = ["Phased release over 7 days", "Release to everyone at once"]
        wanted_phased = choose("Rollout:", options, default=0 if phased else 1) == 0

    plan = (
        ([f"attach {describe_build(chosen)}"] if attach else [])
        + (["declare the build encryption-exempt"] if declare_exempt else [])
        + plan_release_options(current_type, phased is not None, wanted_type, wanted_phased)
    )
    if not plan:
        print("build: nothing to do")
    elif args.dry_run:
        print("build: dry run, would " + "; ".join(plan))
    else:
        if declare_exempt:
            client.set_encryption_exempt(chosen["id"])
        if attach:
            client.attach_build(asc_version["id"], chosen["id"])
        if wanted_type and wanted_type != current_type:
            client.set_release_type(asc_version["id"], wanted_type)
        if wanted_phased and phased is None:
            client.create_phased_release(asc_version["id"])
        elif wanted_phased is False and phased is not None:
            client.delete_phased_release(phased["id"])
        print("build: " + "; ".join(plan))
    return chosen is not None


def plan_updates(notes: dict[str, str], localizations: list[dict]) -> tuple[list[dict], list[str]]:
    """Pairs every App Store locale with its section (or `[default]`); returns rows and warnings."""
    rows = []
    present = set()
    for loc in localizations:
        locale = loc["attributes"]["locale"]
        key = locale.lower()
        present.add(key)
        if key in notes:
            source = locale
        elif DEFAULT_SECTION in notes:
            source = DEFAULT_SECTION
        else:
            raise UsageError(f"no section for {locale} and no [{DEFAULT_SECTION}] section")
        text = notes[key if key in notes else DEFAULT_SECTION]
        rows.append(
            {
                "id": loc["id"],
                "locale": locale,
                "source": source,
                "text": text,
                "changed": (loc["attributes"].get("whatsNew") or "") != text,
            }
        )
    warnings = [
        f"section [{key}] has no localization on this version; add the locale in App Store Connect first"
        for key in notes
        if key != DEFAULT_SECTION and key not in present
    ]
    return rows, warnings


def print_table(rows: list[dict]) -> None:
    width = max(len(r["locale"]) for r in rows)
    for row in sorted(rows, key=lambda r: r["locale"]):
        state = "update" if row["changed"] else "unchanged"
        print(f"  {row['locale']:<{width}}  <- [{row['source']}]  {state}")


def step_whats_new(ctx: Context, asc_version: dict, notes: dict[str, str]) -> None:
    client, args = ctx.client, ctx.args
    rows, warnings = plan_updates(notes, client.localizations(asc_version["id"]))
    if not rows:
        raise UsageError(f"version {ctx.version} has no localizations")
    print_table(rows)
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)

    to_update = [r for r in rows if r["changed"]]
    if args.dry_run:
        print(f"what's new: dry run, {len(to_update)} to update, {len(rows) - len(to_update)} unchanged")
        return
    for row in to_update:
        client.set_whats_new(row["id"], row["text"])
    print(f"what's new: updated {len(to_update)}, unchanged {len(rows) - len(to_update)}")


def action_info(ctx: Context) -> int:
    # The notes file is checked before anything is written, so a bad file costs no requests.
    notes = parse_notes(pathlib.Path(ctx.args.notes).read_text(encoding="utf-8"))
    asc_version = ctx.resolve_version(allow_create=True)
    if asc_version is None:
        return 0
    build_ok = step_build(ctx, asc_version)
    step_whats_new(ctx, asc_version, notes)
    return 0 if build_ok else 1


# ---------------------------------------------------------------------------------------------------
# Action 2: manage release (submit to review, publish, phased rollout), by the version's state


def step_submit(ctx: Context, asc_version: dict) -> int:
    client, args = ctx.client, ctx.args

    build = client.attached_build(asc_version["id"])
    if build is None:
        raise UsageError("no build is attached to the version; run action 1 first")
    print(f"build: {describe_build(build)}")
    if build["attributes"].get("usesNonExemptEncryption") is None:
        raise UsageError("the attached build has no export compliance; run action 1 to declare it")

    missing = [
        loc["attributes"]["locale"]
        for loc in client.localizations(asc_version["id"])
        if not (loc["attributes"].get("whatsNew") or "").strip()
    ]
    if missing:
        raise UsageError(f"What's New is empty for {', '.join(sorted(missing))}; run action 1 first")

    # A submission that was created but never sent (version state READY_FOR_REVIEW) is completed
    # rather than duplicated; one already with Apple blocks a new one.
    open_subs = client.open_submissions(ctx.app_id)
    unsent = [s for s in open_subs if s["attributes"]["state"] == "READY_FOR_REVIEW"]
    if open_subs and not unsent:
        states = ", ".join(s["attributes"]["state"] for s in open_subs)
        raise UsageError(f"an iOS review submission is already with Apple ({states}); wait for it in App Store Connect")
    if unsent and asc_version["attributes"].get("appVersionState") != "READY_FOR_REVIEW":
        raise UsageError(
            f"an unsent review submission exists without {ctx.version} in it; add the version to it or delete it in App Store Connect"
        )

    if args.dry_run:
        print(f"dry run: would submit {ctx.version} to App Review")
        return 0
    if not args.yes and not confirm(f"Submit {ctx.version} to App Review?"):
        raise UsageError("not submitted; pass --yes (make YES=1) to submit without asking")

    if unsent:
        submission_id = unsent[0]["id"]
    else:
        submission_id = client.create_submission(ctx.app_id)
        client.add_submission_item(submission_id, asc_version["id"])
    client.submit(submission_id)
    print(f"submitted {ctx.version} to App Review")
    return 0


def step_publish(ctx: Context, asc_version: dict, phased: dict | None) -> int:
    client, args = ctx.client, ctx.args
    build = client.attached_build(asc_version["id"])
    if build is None:
        raise UsageError("no build is attached to the version; nothing to release or tag")
    print(f"build: {describe_build(build)}")
    audience = "1% of users with automatic updates on day 1, everyone by day 7" if phased else "everyone"

    # The tag is resolved before the release so a missing branch or a misplaced tag stops the run while
    # nothing irreversible has happened yet.
    tag = release_tag(ctx.version, build["attributes"]["version"])
    branch = release_branch(ctx.version)
    if args.commit:
        commit = resolve_commit(args.commit)
        source = args.commit
    else:
        # App Store Connect records no git SHA, so the branch tip stands in for the built commit. A tip
        # committed after the upload cannot be in the build: the operator names the right commit instead.
        commit = release_commit(ctx.version)
        source = branch
        committed, uploaded = committer_date(commit), build["attributes"].get("uploadedDate")
        if tip_after_upload(committed, uploaded):
            raise UsageError(
                f"{branch} moved after build {build['attributes']['version']} was uploaded "
                f"(tip {commit[:7]} committed {committed}, build uploaded {uploaded}); "
                f"pass --commit <sha> (make COMMIT=<sha>) to tag the commit the build came from"
            )
    decision = tag_decision(tag, remote_tag(tag), local_tag(tag), commit)
    tagging = f"tag {tag} at {source} ({commit[:7]}) and push it to {GIT_REMOTE}"
    print(f"tag: {tag} -> {source} ({commit[:7]}){' (already tagged)' if decision == 'skip' else ''}")

    if args.dry_run:
        print(f"dry run: would release {ctx.version} to the App Store ({audience})" + (f" and {tagging}" if decision == "tag" else ""))
        return 0
    question = f"Release {ctx.version} to the App Store ({audience})" + (f" and {tagging}" if decision == "tag" else "") + "?"
    if not args.yes and not confirm(question):
        raise UsageError("not released; pass --yes (make YES=1) to release without asking")
    client.release_version(asc_version["id"])
    print(f"released {ctx.version} to {audience}")
    if decision == "skip":
        return 0
    try:
        push_tag(tag, commit)
    except UsageError as error:
        print(
            f"warning: released, but the tag was not pushed: {error}\n"
            f"  push it by hand: git push {GIT_REMOTE} {commit}:refs/tags/{tag}",
            file=sys.stderr,
        )
        return 1
    print(f"tagged {tag} ({commit[:7]}) and pushed it to {GIT_REMOTE}")
    return 0


def step_rollout(ctx: Context, asc_version: dict, phased: dict) -> int:
    client, args = ctx.client, ctx.args
    state = phased["attributes"].get("phasedReleaseState")
    transitions = rollout_transitions(state)
    keys = "|".join(key for key, _, _ in transitions)
    if args.rollout:
        chosen = next((t for t in transitions if t[0] == args.rollout), None)
        if chosen is None:
            raise UsageError(f"cannot {args.rollout} a rollout that is {state.lower()} (allowed: {keys})")
    elif not interactive():
        raise UsageError(f"pass --rollout {keys} (make ROLLOUT=...) when there is no terminal")
    else:
        chosen = transitions[choose("Rollout:", [label for _, label, _ in transitions])]
    _, label, target = chosen

    if args.dry_run:
        print(f"dry run: would {label.lower()} for {ctx.version}")
        return 0
    if not args.yes and not confirm(f"{label} for {ctx.version}?"):
        raise UsageError("rollout unchanged; pass --yes (make YES=1) to change it without asking")
    client.set_phased_release_state(phased["id"], target)
    print(f"done: {label.lower()}; rollout: {describe_phased_release(client.phased_release(asc_version['id']))}")
    return 0


def lookup_version(ctx: Context) -> tuple[dict, dict | None]:
    """The version in any state (no creation, no editability check) and its phased release."""
    asc_version = ctx.client.app_store_version(ctx.app_id, ctx.version)
    if asc_version is None:
        raise UsageError(f"no iOS App Store version {ctx.version} for {ctx.args.bundle_id}; run action 1 first")
    phased = ctx.client.phased_release(asc_version["id"])
    print(f"{ctx.args.bundle_id} {ctx.version} ({asc_version['attributes'].get('appVersionState')})")
    print(describe_release_options(asc_version["attributes"].get("releaseType"), phased))
    return asc_version, phased


def action_release(ctx: Context) -> int:
    """One step per run, chosen by the version's state: submit, publish, or change the rollout."""
    asc_version, phased = lookup_version(ctx)
    state = asc_version["attributes"].get("appVersionState")

    if state in IN_REVIEW_STATES:
        print("in review; nothing to do until App Review finishes")
        return 0
    if state in EDITABLE_STATES or state == "READY_FOR_REVIEW":
        return step_submit(ctx, asc_version)
    if state == "PENDING_DEVELOPER_RELEASE":
        return step_publish(ctx, asc_version, phased)
    if state == "PENDING_APPLE_RELEASE":
        print("approved; Apple releases it (release type is not manual)")
        return 0
    if state in RELEASED_STATES:
        if phased and rollout_transitions(phased["attributes"].get("phasedReleaseState")):
            return step_rollout(ctx, asc_version, phased)
        print("released to everyone; nothing to do")
        return 0
    raise UsageError(f"version {ctx.version} is in state {state}; nothing to do from the terminal")


# ---------------------------------------------------------------------------------------------------
# Action 3: post the release status to Slack


def action_status(ctx: Context) -> int:
    asc_version, phased = lookup_version(ctx)
    client, args = ctx.client, ctx.args
    label = status_label(asc_version["attributes"], phased)
    if label is None:
        print(f"nothing to announce for state {asc_version['attributes'].get('appVersionState')}")
        return 0
    slack = release_slack()
    build = client.attached_build(asc_version["id"])
    text = slack.slack_message("ios", ctx.version, build["attributes"].get("version") if build else None, label)
    print("message:\n" + "\n".join("  " + line for line in text.splitlines()))
    if args.dry_run:
        print("dry run: not posted")
        return 0
    if not args.yes and not confirm("Post to Slack?"):
        raise UsageError("not posted; pass --yes (make YES=1) to post without asking")
    try:
        slack.post_slack(text)
    except slack.SlackError as error:
        raise UsageError(str(error)) from None
    print("posted")
    return 0


# ---------------------------------------------------------------------------------------------------
# Self-test: parser and the DER -> raw signature conversion, with a throwaway key


def self_test() -> int:
    notes = parse_notes("# comment\n\n[default]\nFixes.\n\n[ru]\nПравки.\nЕщё строка.\n\n[en-US]\n\nHello\n")
    assert notes == {"default": "Fixes.", "ru": "Правки.\nЕщё строка.", "en-us": "Hello"}, notes
    for bad in ("", "text\n[default]\nx", "[a]\nx\n[a]\ny", "[a]\n\n"):
        try:
            parse_notes(bad)
        except UsageError:
            pass
        else:
            raise AssertionError(f"accepted bad notes: {bad!r}")

    rows, warnings = plan_updates(
        {"default": "D", "ru": "R"},
        [
            {"id": "1", "attributes": {"locale": "ru", "whatsNew": "R"}},
            {"id": "2", "attributes": {"locale": "en-US", "whatsNew": "old"}},
        ],
    )
    assert [(r["locale"], r["source"], r["changed"]) for r in rows] == [("ru", "ru", False), ("en-US", "default", True)]
    assert warnings == []
    assert plan_updates({"default": "D", "de-de": "X"}, [{"id": "1", "attributes": {"locale": "ru"}}])[1]

    october = time.strptime("2026-10-22", "%Y-%m-%d")
    assert next_version("26.10.3", october) == "26.10.4"
    assert next_version("26.09.4", october) == "26.10.0"
    assert next_version("25.10.1", october) == "26.10.0"

    released = {"appVersionState": "READY_FOR_DISTRIBUTION"}
    phased_day = lambda day, state="ACTIVE": {"attributes": {"phasedReleaseState": state, "currentDayNumber": day}}  # noqa: E731
    assert status_label({"appVersionState": "WAITING_FOR_REVIEW"}, None) == "waiting for review"
    assert status_label({"appVersionState": "IN_REVIEW"}, None) == "waiting for review"
    assert status_label({"appVersionState": "READY_FOR_REVIEW"}, None) is None
    assert status_label({"appVersionState": "PENDING_DEVELOPER_RELEASE"}, phased_day(1, "INACTIVE")) is None
    assert status_label({"appVersionState": "PREPARE_FOR_SUBMISSION"}, None) is None
    assert [status_label(released, phased_day(d)) for d in range(1, 8)] == ["1%", "2%", "5%", "10%", "20%", "50%", "100%"]
    assert status_label(released, phased_day(3, "PAUSED")) == "5%"
    assert status_label(released, phased_day(7, "COMPLETE")) == "100%"
    assert status_label(released, None) == "100%"

    assert release_branch("26.10.4") == "release/ios/26.10.4"
    assert release_tag("26.10.4", "1234") == "ios/26.10.4_1234"
    assert not tip_after_upload("2026-10-20T10:00:00+03:00", "2026-10-20T12:00:00-07:00")
    assert not tip_after_upload("2026-10-20T10:00:00+00:00", "2026-10-20T10:00:00Z")
    assert tip_after_upload("2026-10-21T09:00:00+00:00", "2026-10-20T12:00:00-07:00")
    assert tip_after_upload("2026-10-20T20:00:00+00:00", "2026-10-20T12:00:00-07:00")
    assert not tip_after_upload("2026-10-21T09:00:00+00:00", None)
    a, b = "a" * 40, "b" * 40
    assert tag_decision("ios/26.10.4_1234", None, None, a) == "tag"
    assert tag_decision("ios/26.10.4_1234", None, a, a) == "tag", "a local-only tag is not published yet"
    assert tag_decision("ios/26.10.4_1234", a, None, a) == "skip"
    assert tag_decision("ios/26.10.4_1234", a, a, a) == "skip"
    assert tag_decision("ios/26.10.4_1234", a, b, a) == "skip", "published already; the stale local tag is not pushed"
    for remote, local in ((b, None), (b, a), (None, b)):
        try:
            tag_decision("ios/26.10.4_1234", remote, local, a)
        except UsageError:
            pass
        else:
            raise AssertionError(f"accepted a tag on another commit (remote={remote}, local={local})")

    assert plan_release_options("MANUAL", True, None, None) == []
    assert plan_release_options("MANUAL", True, "MANUAL", True) == []
    assert plan_release_options("AFTER_APPROVAL", False, "MANUAL", True) == [
        "set release type to manual",
        "enable phased release",
    ]
    assert plan_release_options("MANUAL", True, "AFTER_APPROVAL", False) == [
        "set release type to after approval",
        "disable phased release",
    ]
    assert plan_release_options(None, False, None, True) == ["enable phased release"]
    assert [k for k, _, _ in rollout_transitions("ACTIVE")] == ["pause", "complete"]
    assert [k for k, _, _ in rollout_transitions("PAUSED")] == ["resume", "complete"]
    assert all(rollout_transitions(s) == () for s in ("INACTIVE", "COMPLETE", None))
    assert describe_phased_release(None) == "everyone at once"
    assert describe_phased_release({"attributes": {"phasedReleaseState": "INACTIVE"}}) == "phased over 7 days (not started)"
    active = {"attributes": {"phasedReleaseState": "ACTIVE", "currentDayNumber": 3, "startDate": "2026-10-20T10:00:00Z"}}
    assert describe_phased_release(active) == "phased over 7 days, active, day 3 of 7, started 2026-10-20"

    with tempfile.TemporaryDirectory() as tmp:
        key = pathlib.Path(tmp) / "key.p8"
        pub = pathlib.Path(tmp) / "key.pub"
        subprocess.run(["openssl", "ecparam", "-genkey", "-name", "prime256v1", "-noout", "-out", str(key)], check=True)
        subprocess.run(["openssl", "ec", "-in", str(key), "-pubout", "-out", str(pub)], check=True, capture_output=True)
        token = make_jwt("KEYID", "ISSUER", key)
        head, claims, sig = token.split(".")
        raw = base64.urlsafe_b64decode(sig + "=" * (-len(sig) % 4))
        assert len(raw) == 64, len(raw)

        # Re-encode r||s as DER and let openssl verify it against the signing input.
        def enc(v: bytes) -> bytes:
            stripped = v.lstrip(b"\x00") or b"\x00"
            if stripped[0] & 0x80:
                stripped = b"\x00" + stripped
            return b"\x02" + bytes([len(stripped)]) + stripped

        body = enc(raw[:32]) + enc(raw[32:])
        sig_file = pathlib.Path(tmp) / "sig.der"
        sig_file.write_bytes(b"\x30" + bytes([len(body)]) + body)
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", str(pub), "-signature", str(sig_file)],
            input=f"{head}.{claims}".encode(),
            capture_output=True,
            check=False,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        decoded = json.loads(base64.urlsafe_b64decode(head + "=="))
        assert decoded == {"alg": "ES256", "kid": "KEYID", "typ": "JWT"}, decoded
    print("self-test ok")
    return 0


# ---------------------------------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("action", nargs="?", choices=[name for name, _ in ACTIONS], help="skip the chooser")
    parser.add_argument("--notes", default=str(pathlib.Path(__file__).resolve().with_name("whats_new.txt")), help="notes file")
    parser.add_argument("--version", help="App Store version string (default: APP_VERSION_COMMON from common.xcconfig)")
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    parser.add_argument("--build", help="build number to attach (default: choose from the processed builds)")
    parser.add_argument("--dry-run", action="store_true", help="show what would change without writing")
    parser.add_argument("--create", action="store_true", help="create the App Store version if it does not exist, without asking")
    parser.add_argument(
        "--encryption-exempt",
        action="store_true",
        help="declare a build without export compliance as using only exempt encryption, without asking",
    )
    parser.add_argument("--release", choices=sorted(RELEASE_TYPES), help="release type for the version (default: ask, or keep)")
    parser.add_argument("--phased-release", choices=("on", "off"), help="phased 7-day rollout (default: ask, or keep)")
    parser.add_argument("--rollout", choices=("pause", "resume", "complete"), help="phased rollout change (default: ask)")
    parser.add_argument(
        "--commit",
        help="commit to tag when publishing (default: the tip of release/ios/<version>, refused if newer than the build)",
    )
    parser.add_argument("--yes", action="store_true", help="submit, release, change the rollout or post to Slack without asking")
    parser.add_argument("--self-test", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    try:
        shared = release_slack(required=False)
        if shared:
            shared.load_env_file(repo_root() / ".env")
        else:
            print("note: shared/scripts/ is not in this checkout; .env is not read, set the credentials in the environment", file=sys.stderr)
        action = args.action
        if action is None:
            if not interactive():
                raise UsageError(f"pass an action ({', '.join(name for name, _ in ACTIONS)}) when there is no terminal")
            action = ACTIONS[choose("App Store Connect:", [label for _, label in ACTIONS])][0]

        version = args.version or default_version()
        if not version:
            raise UsageError("pass --version; APP_VERSION_COMMON was not found in Configurations/common.xcconfig")
        key_id = os.environ.get("ASC_KEY_ID")
        issuer_id = os.environ.get("ASC_ISSUER_ID")
        if not key_id or not issuer_id:
            raise UsageError("set ASC_KEY_ID and ASC_ISSUER_ID (env or the repository-root .env)")
        with PrivateKey() as key_path:
            client = AscClient(make_jwt(key_id, issuer_id, key_path))

        ctx = Context(client, args, version)
        actions = {"info": action_info, "release": action_release, "status": action_status}
        return actions[action](ctx)
    except (UsageError, AscError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
