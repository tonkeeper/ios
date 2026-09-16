# iOS Maestro Breaking-Change Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a PR-triggered GitHub Actions workflow to ios_private that warns (inline PR comments, with concrete fix suggestions) when a change likely breaks a Maestro UI test, plus opt-in Claude overview/review jobs ported from android_private.

**Architecture:** One new workflow file `.github/workflows/claude.yml` with three jobs: `overview` and `review` (opt-in via PR-body markers, opened/reopened only — parity with android_private branch `feature/maestro-impact-guard`), and `maestro-guard` (every opened/reopened/synchronize, bash path pre-gate before the Claude invocation, advisory via `continue-on-error`). The guard is a prompt-driven `claude-code-action` step: it maps changed iOS locator sources (accessibility identifiers, `en.lproj/Localizable.strings` values, inline Swift literals) to Maestro flow locators and posts inline comments with fixes.

**Tech Stack:** GitHub Actions, `anthropics/claude-code-action` (SHA `38ec876110f9fbf8b950c79f534430740c3ac009`), `gh` CLI, bash.

## Global Constraints

- Guard must be read-only: comments only; never edit files, push, or open PRs.
- Guard must never block merge: job has `continue-on-error: true`.
- Models: guard `claude-sonnet-4-5-20250929`; review `claude-opus-4-6`; overview `claude-sonnet-4-5-20250929` (parity with Android).
- Path gate regex: `^(LocalPackages/|Tonkeeper/|TonkeeperWidget/).*\.(swift|strings|xcstrings|storyboard|xib)$`
- Default locale file: `LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings`
- Prerequisite (out of band, repo admin): add `ANTHROPIC_API_KEY` secret to ios_private (Anthropic API key from console.anthropic.com, not the subscription OAuth token).

---

### Task 1: Create `.github/workflows/claude.yml`

**Files:**
- Create: `.github/workflows/claude.yml`

**Interfaces:**
- Consumes: repo secrets `ANTHROPIC_API_KEY` (to be added by admin), `github.token` for the gate step.
- Produces: workflow jobs `overview`, `review`, `maestro-guard`; guard gate step output `steps.gate.outputs.hit` (`"true"`/`"false"`).

- [ ] **Step 1: Write the workflow file** with exactly this content:

```yaml
name: Claude PR Review

on:
  pull_request:
    types: [ opened, reopened, synchronize ]

permissions:
  pull-requests: write
  contents: read
  id-token: write

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  overview:
    if: >-
      github.event.action != 'synchronize' &&
      (contains(github.event.pull_request.body, '/claude-overview') || contains(github.event.pull_request.body, '@claude'))
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Main changes summary
        uses: anthropics/claude-code-action@38ec876110f9fbf8b950c79f534430740c3ac009 # v1.0.101
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          settings: '{"permissions":{"allow":["Bash(gh pr comment:*)","Bash(gh pr diff:*)","Bash(gh pr view:*)"]}}'
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            You are a senior software engineer reviewing a pull request.

            Provide a concise summary of the main changes.
            Group changes by area/module when possible.
            Use bullet points. Be specific but brief.
            Do NOT mention security concerns.

            If commit messages or the diff contain task numbers (e.g. TK-123, IOS-456),
            list them at the top of your summary under a "Related Tasks" heading.

            After composing your summary, post it as a single PR comment using:
            gh pr comment <PR_NUMBER> --repo ${{ github.repository }} --body "<your summary>"
          claude_args: |
            --max-turns 8
            --model claude-sonnet-4-5-20250929
            --allowedTools "Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"

  review:
    if: >-
      github.event.action != 'synchronize' &&
      (contains(github.event.pull_request.body, '/claude-review') || contains(github.event.pull_request.body, '@claude'))
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - uses: anthropics/claude-code-action@38ec876110f9fbf8b950c79f534430740c3ac009 # v1.0.101
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          settings: '{"permissions":{"allow":["Bash(gh pr comment:*)","Bash(gh pr diff:*)","Bash(gh pr view:*)"]}}'
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            You are a senior software engineer performing a thorough code review on an iOS (Swift) project.

            Provide actionable feedback. Focus on:
            - Bugs and logic errors
            - Performance issues
            - Security issues
            - Code readability and maintainability
            - Swift, UIKit and SwiftUI best practices
            - Memory management (retain cycles, capture lists)
            - Concurrency issues (async/await, actor isolation, main-thread UI updates)
            - Error handling gaps

            For each issue found, reference the file name and provide a clear explanation.
            Do NOT comment on things that are correct or well-written — only comment on actual problems.
            If the code looks good and has no issues, post a single brief PR comment saying so.
            Do not invent problems. Be constructive and concise.

            Use inline comments for specific issues found in the code.
          claude_args: |
            --max-turns 25
            --model claude-opus-4-6
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"

  maestro-guard:
    name: Maestro breaking-change guard
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Gate on UI-relevant changed paths
        id: gate
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          if gh pr diff ${{ github.event.pull_request.number }} \
               --repo ${{ github.repository }} --name-only \
             | grep -qE '^(LocalPackages/|Tonkeeper/|TonkeeperWidget/).*\.(swift|strings|xcstrings|storyboard|xib)$'; then
            echo "hit=true" >> "$GITHUB_OUTPUT"
          else
            echo "hit=false" >> "$GITHUB_OUTPUT"
            echo "No UI-relevant paths changed — skipping Maestro guard." >> "$GITHUB_STEP_SUMMARY"
          fi

      - name: Maestro breaking-change guard
        if: steps.gate.outputs.hit == 'true'
        uses: anthropics/claude-code-action@38ec876110f9fbf8b950c79f534430740c3ac009 # v1.0.101
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          settings: '{"permissions":{"allow":["Bash(gh pr diff:*)","Bash(gh pr view:*)"]}}'
          # Inlined analysis prompt for the Maestro breaking-change guard (iOS).
          prompt: |
            You are a CI guard that detects when a pull request may break Maestro UI tests.
            You run in your own isolated context on every pull request update.

            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            STEP 0 — SELF-GATE:
            Run `gh pr diff ${{ github.event.pull_request.number }} --repo ${{ github.repository }} --name-only`.
            If none of the changed paths match
            `(LocalPackages/|Tonkeeper/|TonkeeperWidget/).*\.(swift|strings|xcstrings|storyboard|xib)$`,
            there is nothing to analyze — post nothing and exit. Do not read the suite.

            CONTEXT:
            Maestro flows live in `maestro_ui_tests/`. Flows
            (`maestro_ui_tests/flows/ton-state/**` and `maestro_ui_tests/flows/multichain/**`)
            include reusable steps via `runFlow: <path>` from `maestro_ui_tests/steps/**`
            and `maestro_ui_tests/service/**`. A locator used in a step or service file
            therefore affects every flow that runFlows it (directly or transitively).

            Flows target UI elements two ways:
            - `id: <value>` → an iOS accessibility identifier, set in Swift either as
              a UIKit assignment `accessibilityIdentifier = "<value>"` or as a SwiftUI
              modifier `.accessibilityIdentifier("<value>")`.
            - `text: <value>` / bare `tapOn: <value>` / `assertVisible: <value>` →
              visible UI text, from an inline Swift string literal rendered in UI, or
              from the default-locale strings file
              `LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings`
              (entries look like `"some.key" = "VALUE";` — flows match by VALUE, not by key).

            ANALYSIS STEPS:
            1. Get the full diff: `gh pr diff ${{ github.event.pull_request.number }} --repo ${{ github.repository }}`.
            2. Extract every changed token that could alter a locator:
               - renamed/removed `accessibilityIdentifier = "<value>"` or
                 `.accessibilityIdentifier("<value>")`,
               - changed/removed `"key" = "VALUE";` entries in the default
                 `en.lproj/Localizable.strings` (the VALUE part),
               - changed/removed inline Swift string literals that are rendered in UI
                 (e.g. passed to `Text(...)`, a `title`, a button label).
            3. For each token, search the WHOLE suite for flows that depend on it:
               - Grep `maestro_ui_tests/` for the token used as `id:`, `text:`,
                 `tapOn:`, or `assertVisible:`.
               - If the match is in `maestro_ui_tests/steps/**` or `.../service/**`,
                 trace `runFlow:` references back to the flow file(s) under `.../flows/**`.
            4. Judge, per affected flow, whether the change likely BREAKS it (the
               value the test targets no longer exists / changed). Assign
               confidence high / medium / low.

            RULES:
            - Only READ and comment. Never edit files, never push, never open PRs.
            - Do not flag a change that does not touch a locator some flow actually uses.
            - Common words ("Open", "Continue", "Connect wallet", "Confirm") appear
              widely — only flag when a flow targets that exact text AND the change
              alters that exact value.
            - Ignore dynamic or interpolated identifiers: Swift interpolation
              (`\(...)`), values built from variables or nil-coalescing, and Maestro
              locators containing `${...}`.
            - Ignore regex text locators in flows (values containing `.*`).
            - Ignore non-default locales (any `*.lproj` other than `en.lproj`) unless
              the same value also changed in `en.lproj/Localizable.strings`.

            OUTPUT:
            For each affected flow with high or medium confidence, post ONE inline
            comment on the changed line using
            `mcp__github_inline_comment__create_inline_comment`, structured as:

            1. The warning:
               ⚠️ May break Maestro flow `<flow path>` — this change alters locator
               `<value>` used at `<flow-or-step file>`.
            2. A concrete suggested fix:
               - If the break is fixed by keeping the old locator value on the changed
                 line itself (e.g. an identifier was renamed without need), include a
                 GitHub suggestion block (```suggestion) with the corrected line so it
                 can be applied in one click.
               - Otherwise (the app change is intentional and the TEST must adapt),
                 include a fenced YAML snippet naming the exact flow/step file and
                 showing the replacement line(s) with the new locator value.

            If nothing is affected, or all matches are low-confidence, post NOTHING
            and exit successfully. Silence is the correct result for a clean PR.
          claude_args: |
            --max-turns 15
            --model claude-sonnet-4-5-20250929
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Read,Grep,Glob,Bash(gh pr diff:*),Bash(gh pr view:*)"
```

- [ ] **Step 2: Validate YAML syntax**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/claude.yml')); print('YAML OK')"`
Expected: `YAML OK`
If `actionlint` is installed (`command -v actionlint`), also run `actionlint .github/workflows/claude.yml` — expected: no output (clean).

- [ ] **Step 3: Dry-verify guard assumptions against the repo**

Run each; every one must return at least one match:
```bash
grep -rn 'accessibilityIdentifier = "' LocalPackages | head -3
grep -rn '\.accessibilityIdentifier("' LocalPackages | head -3
head -5 LocalPackages/TKLocalize/Sources/TKLocalize/Resources/Locales/en.lproj/Localizable.strings
grep -rn 'runFlow' maestro_ui_tests/flows | head -3
```
Also verify the gate regex matches a real recent PR: `gh pr diff 988 --repo tonkeeper/ios_private --name-only | grep -E '^(LocalPackages/|Tonkeeper/|TonkeeperWidget/).*\.(swift|strings|xcstrings|storyboard|xib)$' | head -3` (expected: swift paths listed).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/claude.yml docs/superpowers/specs/2026-07-30-maestro-impact-guard-ios-design.md docs/superpowers/plans/2026-07-30-maestro-impact-guard-ios.md
git commit -m "feat(ci): add Claude PR review workflow with Maestro breaking-change guard

Ports android_private's claude.yml (overview + review, opt-in via PR body)
and adds an iOS-adapted Maestro guard job that runs on every PR update,
maps accessibility identifiers / Localizable.strings values / inline UI
literals to Maestro locators, and posts inline warnings with suggested
fixes. Advisory only (continue-on-error); requires ANTHROPIC_API_KEY
secret.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Surface the secret prerequisite

**Files:**
- None (operational step).

**Interfaces:**
- Consumes: nothing.
- Produces: admin instruction in final report.

- [ ] **Step 1: Confirm secret still absent**

Run: `gh secret list --repo tonkeeper/ios_private | grep -c CLAUDE || true`
Expected: `0`

- [ ] **Step 2: Report** — final summary must tell the user: repo admin adds `ANTHROPIC_API_KEY` (Anthropic API key from console.anthropic.com) via Settings → Secrets and variables → Actions, or `gh secret set ANTHROPIC_API_KEY --repo tonkeeper/ios_private`. Until then all three jobs fail at the Claude step (gate step still works).
