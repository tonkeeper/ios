#!/usr/bin/env python3
"""App Store Connect release tooling for the iOS app: prepare the build, push "What's New", submit for review.

Each release needs the same three clicks-through in App Store Connect: pick the processed build for the
version, type the release notes per locale, and send the version to review. `make appstore_toolings` does
them from the terminal (a numbered chooser, or `ACTION=build|whats-new|submit` to skip it) so the release
notes go through a PR (`scripts/appstore/whats_new.txt`) and the steps are repeatable.

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

ACTIONS = (
    ("build", "Prepare build info (attach the processed build to the version)"),
    ("whats-new", "Update What's New from scripts/appstore/whats_new.txt"),
    ("submit", "Submit the version to App Review"),
)


class UsageError(Exception):
    """A problem the user can fix: bad file, missing credentials, no such version."""


# ---------------------------------------------------------------------------------------------------
# Paths, environment, terminal


def ios_root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[2]


def repo_root() -> pathlib.Path:
    return ios_root().parent


def load_env_file(path: pathlib.Path) -> None:
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


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
    VERSION_FIELDS = {"fields[appStoreVersions]": "versionString,appVersionState,platform"}
    BUILD_FIELDS = {"fields[builds]": "version,uploadedDate,processingState,usesNonExemptEncryption,expired,buildAudienceType"}

    def __init__(self, token: str) -> None:
        self._token = token

    def request(self, method: str, path_or_url: str, body: dict | None = None) -> dict:
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
                raise UsageError("create the version first (action 1 or 2 offers to)")
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
            raise UsageError(f"version {self.version} is in state {state}; it can no longer be edited")
        return asc_version


def describe_build(build: dict) -> str:
    attrs = build["attributes"]
    uploaded = (attrs.get("uploadedDate") or "")[:16].replace("T", " ")
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


# ---------------------------------------------------------------------------------------------------
# Action 1: prepare build info


def action_build(ctx: Context) -> int:
    asc_version = ctx.resolve_version(allow_create=True)
    if asc_version is None:
        return 0
    client, args = ctx.client, ctx.args

    current = client.attached_build(asc_version["id"])
    if current:
        print(f"attached: {describe_build(current)}")

    builds = client.builds(ctx.app_id, ctx.version)
    blockers = {b["id"]: build_blocker(b, ctx.version) for b in builds}
    valid = [b for b in builds if blockers[b["id"]] is None]
    if not valid:
        states = ", ".join(f"{b['attributes'].get('version')} ({blockers[b['id']]})" for b in builds) or "none"
        raise UsageError(f"no attachable build for {ctx.version} (builds: {states}); upload one or wait for processing")

    if args.build:
        chosen = next((b for b in builds if b["attributes"].get("version") == args.build), None)
        if chosen is None:
            raise UsageError(f"build {args.build} is not a build of {ctx.version}")
        if blockers[chosen["id"]]:
            raise UsageError(f"build {args.build} cannot be attached: {blockers[chosen['id']]}")
    else:
        chosen = valid[choose(f"Attachable builds of {ctx.version}, newest first:", [describe_build(b) for b in valid])]

    attach = not current or current["id"] != chosen["id"]
    # Export compliance is a legal declaration, so it has its own consent: the prompt or --encryption-exempt.
    # --create only covers creating the version.
    declare_exempt = False
    if chosen["attributes"].get("usesNonExemptEncryption") is None:
        declare_exempt = args.encryption_exempt or confirm(
            "The build has no export compliance. Declare it uses only exempt encryption?"
        )
        if not declare_exempt:
            print(
                "warning: export compliance stays missing; App Review will not accept the build "
                "(pass --encryption-exempt / make ENCRYPTION_EXEMPT=1 to declare it without asking)",
                file=sys.stderr,
            )

    plan = ([f"attach {describe_build(chosen)}"] if attach else []) + (
        ["declare the build encryption-exempt"] if declare_exempt else []
    )
    if not plan:
        print("build already attached, nothing to do")
        return 0
    if args.dry_run:
        print("dry run: would " + "; ".join(plan))
        return 0
    if declare_exempt:
        client.set_encryption_exempt(chosen["id"])
    if attach:
        client.attach_build(asc_version["id"], chosen["id"])
    print("done: " + "; ".join(plan))
    return 0


# ---------------------------------------------------------------------------------------------------
# Action 2: update What's New


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


def action_whats_new(ctx: Context) -> int:
    notes = parse_notes(pathlib.Path(ctx.args.notes).read_text(encoding="utf-8"))
    asc_version = ctx.resolve_version(allow_create=True)
    if asc_version is None:
        return 0
    client, args = ctx.client, ctx.args

    rows, warnings = plan_updates(notes, client.localizations(asc_version["id"]))
    if not rows:
        raise UsageError(f"version {ctx.version} has no localizations")
    print_table(rows)
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)

    to_update = [r for r in rows if r["changed"]]
    if args.dry_run:
        print(f"dry run: {len(to_update)} to update, {len(rows) - len(to_update)} unchanged")
        return 0
    for row in to_update:
        client.set_whats_new(row["id"], row["text"])
    print(f"updated {len(to_update)}, unchanged {len(rows) - len(to_update)}")
    return 0


# ---------------------------------------------------------------------------------------------------
# Action 3: submit to review


def action_submit(ctx: Context) -> int:
    asc_version = ctx.resolve_version(allow_create=False)
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
        raise UsageError(f"What's New is empty for {', '.join(sorted(missing))}; run action 2 first")

    open_subs = client.open_submissions(ctx.app_id)
    if open_subs:
        states = ", ".join(s["attributes"]["state"] for s in open_subs)
        raise UsageError(f"an iOS review submission is already open ({states}); finish or cancel it in App Store Connect")

    if args.dry_run:
        print(f"dry run: would submit {ctx.version} to App Review")
        return 0
    if not args.yes and not confirm(f"Submit {ctx.version} to App Review?"):
        raise UsageError("not submitted; pass --yes (make YES=1) to submit without asking")

    submission_id = client.create_submission(ctx.app_id)
    client.add_submission_item(submission_id, asc_version["id"])
    client.submit(submission_id)
    print(f"submitted {ctx.version} to App Review")
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
    parser.add_argument("--yes", action="store_true", help="submit to review without asking")
    parser.add_argument("--self-test", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    load_env_file(repo_root() / ".env")
    try:
        action = args.action
        if action is None:
            if not interactive():
                raise UsageError("pass an action (build, whats-new, submit) when there is no terminal")
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
        return {"build": action_build, "whats-new": action_whats_new, "submit": action_submit}[action](ctx)
    except (UsageError, AscError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
