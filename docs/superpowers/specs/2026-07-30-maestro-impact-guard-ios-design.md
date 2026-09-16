# iOS Maestro Breaking-Change Guard — Design

Date: 2026-07-30
Status: approved

## Goal

Port the Android `feature/maestro-impact-guard` CI check to ios_private: an AI
step that analyzes each pull request and warns, via inline PR comments, when a
change likely breaks a Maestro UI test — adapted to iOS locator mechanics, and
extended (beyond the Android version) to include a concrete fix suggestion in
each warning.

## Background

- Android version: an extra `claude-code-action` step in the `review` job of
  `.github/workflows/claude.yml` (android_private, branch
  `feature/maestro-impact-guard`). Opt-in via `/claude-review` in the PR body.
- iOS repo has no `claude.yml` and no PR-triggered workflow at all.
- PR scan (30 most recent ios_private PRs): zero contain `/claude-review` or
  `@claude` — an opt-in guard would never run on iOS.

## Decisions (approved)

1. **Full `claude.yml` port** — `overview` and `review` jobs ported from
   Android with iOS-adapted prompts, kept opt-in (`/claude-overview`,
   `/claude-review`, `@claude` in PR body), restricted to
   opened/reopened (`github.event.action != 'synchronize'`).
2. **Guard is opt-in** — separate `maestro-guard` job gated on the PR body
   containing `/claude-overview` or `@claude` (team decision: Claude was not
   installed in this repo before, adoption starts with this MR). Runs on
   `opened`, `reopened`, `synchronize`, so an opted-in PR is re-checked on
   every push. A cheap bash pre-gate (`gh pr diff --name-only` vs a path
   regex) additionally skips the Claude invocation when no UI-relevant file
   changed.
3. **Fix suggestions** — each warning comment includes a concrete fix:
   a GitHub ` ```suggestion ` block when the fix lands on a changed diff
   line, otherwise a plain fenced snippet naming the flow/step file and the
   replacement line. The guard remains read-only (comments only).
4. **Advisory, not blocking** — guard job uses `continue-on-error: true`.
5. **Model parity with Android** — guard: `claude-sonnet-4-5-20250929`,
   review: `claude-opus-4-6`, same pinned `claude-code-action` SHA
   (`38ec876110f9fbf8b950c79f534430740c3ac009`).

## iOS locator mapping (guard prompt)

| Maestro locator | iOS source |
|---|---|
| `id: <value>` | `accessibilityIdentifier = "<value>"` (UIKit) or `.accessibilityIdentifier("<value>")` (SwiftUI) |
| `text:` / bare `tapOn:` / `assertVisible:` | `"key" = "<VALUE>";` in `LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings` (matched by VALUE), or an inline Swift string literal rendered in UI |

Path gate regex:
`(LocalPackages/|Tonkeeper/|TonkeeperWidget/).*\.(swift|strings|xcstrings|storyboard|xib)$`

Suite layout: flows in `maestro_ui_tests/flows/{ton-state,multichain}/**`;
shared steps in `maestro_ui_tests/steps/**` and `maestro_ui_tests/service/**`,
included via `runFlow:` — a locator in a step/service file affects every flow
that includes it.

Ignore rules:
- non-`en.lproj` locale files unless the same value changed in `en.lproj`;
- interpolated/dynamic identifiers (`\(...)`, nil-coalesced variables);
- regex text locators in flows (values containing `.*`);
- common words ("Open", "Continue", "Connect wallet") unless a flow targets
  the exact text and the change alters that exact value.

## Prerequisite (admin action)

The workflow authenticates with an Anthropic API key (`anthropic_api_key`
input), not the subscription OAuth token android_private currently uses —
API keys are org-owned, have separate rate limits, and are the sanctioned
path for automation. A repo admin must add the `ANTHROPIC_API_KEY` secret
(Settings → Secrets and variables → Actions) before any job in this
workflow can run.

## Testing

- Workflow YAML validated with actionlint (or `gh` syntax check).
- Guard grep patterns dry-verified against the repo: `accessibilityIdentifier`
  assignments, SwiftUI modifier usage, `Localizable.strings` values, and
  `runFlow` chains all confirmed present in the expected locations.
