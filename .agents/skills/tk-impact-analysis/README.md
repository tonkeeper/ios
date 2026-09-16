# tk-impact-analysis

Compares the current branch with the relevant release branch and suggests test cases from the regress set based on the code changes

## What It Does

The skill:

- detects the current branch in the selected source repository
- fetches release branches from `origin` so the latest release candidates are available locally
- discovers release branches matching `release/YY.MM.Iterator` or `release/YY.MM.Iterator-hotfixiterator`
- compares the current branch with the right release branch automatically:
  - current branch is the latest release -> compare with the previous release
  - current branch is an older release -> compare with the latest release
  - current branch is not a release branch -> compare with the latest release
- reads the platform regression source from `regress.txt`
- analyzes changed code and maps it to relevant regression coverage
- extracts module and feature names from changed paths and uses them as search terms
- highlights changed files that did not match a known QA area
- shows module-aware search terms for unmatched files and flags uncovered functionality explicitly
- recommends which existing regression checks to run
- suggests missing regression blocks to add
- suggests extra exploratory checks based on the diff
- generates:
  - a Markdown report
  - a TXT test collection for the specific run

## Supported Platforms

- `iOS`
- `Android`
- `Web`

By default, the skill:

- uses the nearest parent git repository containing the skill as the source repository for comparison
- looks for platform regression data under `sources/<platform>/...`
- uses the English regression source when an English variant exists, for example `sources/iOS/regress_EN.txt`

## Required Inputs

- `PLATFORM`: `iOS`, `Android`, or `Web`

Optional:

- `SOURCE_REPOSITORY`: custom source repository used for git comparison
- `BASE_BRANCH`: override the current checked out branch
- `RELEASE_BRANCH`: override the auto-selected release branch
- `REPO_PATH`: legacy alias for `SOURCE_REPOSITORY`
- `REGRESS_PATH`: custom `regress.txt` path
- `REPORT_PATH`: custom Markdown report path
- `TESTS_COLLECTION_PATH`: custom TXT test collection path

## Default Output Paths

- report template: `report.md`
- tests template: `test-collection-template.txt`
- run report: `reports/<execution-date>/<platform>/report.md`
- run tests collection: `reports/<execution-date>/<platform>/test-collection.txt`
- raw git bundle: `reports/<execution-date>/<platform>/raw-git-data.txt`

## How To Run

### In an AI agent (Claude Code / Codex / Cursor)

Example with default iOS paths:

```text
Use the tk-impact-analysis skill to analyze iOS impact. Detect the current branch, compare it with the correct release branch automatically, use the current source repository for git comparison, and use the default regress.txt path.
```

Example with custom paths:

```text
Use the tk-impact-analysis skill to perform QA impact analysis for PLATFORM=Web.
Detect the current branch and compare it with the correct release branch automatically.
Use SOURCE_REPOSITORY=/path/to/web-repo and REGRESS_PATH=/path/to/web/regress.txt.
```

### Locally

You can run the local CLI instead of using an AI agent for the repeatable parts of the workflow:

```bash
python3 .agents/skills/tk-impact-analysis/scripts/tk_impact_analysis.py --platform iOS --write-raw
```

Useful options:

- `--base-branch feature/some-branch`
- `--release-branch release/26.02.1`
- `--source-repository /path/to/repo`
- `--regress-path /path/to/regress.txt`
- `--report-path /custom/report.md`
- `--tests-collection-path /custom/test-collection.txt`
- `--date 2026-03-18`
- `--write-raw`

Example with custom paths:

```bash
python3 scripts/tk_impact_analysis.py \
  --platform Web \
  --source-repository /path/to/web-repo \
  --regress-path /path/to/web/regress.txt \
  --write-raw
```

The local runner will:

- resolve default platform paths
- auto-detect the nearest parent git repository as the source repository unless overridden
- fetch release branches from `origin` on every run
- validate the git worktree and branches
- collect diff and commit metadata
- parse `regress.txt`
- generate a heuristic Markdown report
- generate a focused TXT test collection
- optionally generate `raw-git-data.txt` for a later AI refinement pass
- ignore any repo-relative paths listed in `references/excluded-qa-impact-paths.txt` during QA impact mapping

If fetch fails because SSH authentication is required:

1. Run this manually in your own terminal and complete the SSH prompt:
   `python3 .agents/skills/tk-impact-analysis/scripts/tk_impact_analysis.py --platform iOS --write-raw`
2. After telling the agent it is done, the agent should verify that the generated files in `reports/<execution-date>/<platform>/` were updated recently before using them.

The generated TXT test collection includes:

- selected existing regress rows
- suggested tests for unmatched files
- Missing Blocks
- Additional Checks
- ancestor `[SECTION]` rows for any selected regress checks

For selected existing regress rows, the generated TXT collection preserves the original source order from `regress.txt` / `regress_EN.txt` instead of regrouping checks by matched category.

Module-aware matching rules:

- prefer concrete module names from the diff, for example `BatteryRecharge` and `BatteryRefill`
- search `regress.txt` using those names and obvious localized variants, for example `Battery`, `батарейка`, `Recharge`, `Refill`
- if those searches still find no matching regression rows, mark the functionality as new or uncovered and add focused tests

## Recommended Cost-Optimized Flow

1. Run the local script first with `--write-raw`.
2. Let the agent refine the generated `raw-git-data.txt`, `report.md`, and `test-collection.txt` instead of redoing repo discovery.

This keeps the cheap deterministic work local and uses AI mainly for QA judgment and report refinement.

The recommendations are still heuristic, so they should be reviewed by QA before execution.

## Current Workspace Note

At the moment, this repository is the default source repository for `iOS`, and the bundled default regression data present in this workspace is for `iOS`.
If you copy the skill into the Android repository, it will use that repository automatically and only the Android `regress.txt` data needs to exist under `sources/Android/`.
