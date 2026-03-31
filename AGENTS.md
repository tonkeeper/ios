# Repository Guidelines

## Project Structure & Module Organization
- `Tonkeeper/` contains the main iOS app source and shared resources.
- `TonkeeperWidget/` and `TonkeeperIntents/` host extension targets.
- `LocalPackages/` contains Swift Package Manager modules (feature modules, shared UI, core libs).
- `Configurations/` holds `.xcconfig` files for signing and build settings.
- `Tonkeeper.xcodeproj/` is the primary Xcode project entry point.

## Build, Test, and Development Commands

## Agent Build Instructions

#### Build the Tonkeeper target from the repo root using xcodebuild:

```sh
make compile
```

#### Run tests only through `Makefile` from the repo root:

- Use `make` targets; do not run package-local tests via `cd LocalPackages/... && xcodebuild` or `swift test`.
- Package tests are intentionally routed through `Tonkeeper.xcodeproj`, so they use the app-level SwiftPM lockfile at `Tonkeeper.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- Some local package `Package.resolved` files were intentionally removed to prevent standalone package resolution paths from becoming the default workflow.

Common commands:

```sh
make test_tkcore
make test_keeper_core
make test_wallet_core
make test_core_components
make test_tklocalize
make test_tkchart
make test_tron_swift
make test_tkcryptokit
```

Run a specific test suite through the generic entrypoint:

```sh
make test_project_scheme SCHEME=WalletCore TEST_ONLY=KeeperCoreTests/TonkeeperDeeplinksParserTests
```

Run a single test method:

```sh
make test_project_scheme SCHEME=WalletCore TEST_ONLY=KeeperCoreTests/TonkeeperDeeplinksParserTests/testActionParsing
```

## Key Decisions
- **Worktrees**: Always perform refactoring or new feature work in a dedicated git worktree located under `worktrees/` directory in the repository root to maintain a clean environment and avoid permission issues.

## Skills Usage
- **Task context**: Use `.codex/skills/linear/SKILL.md` to fetch task details when you need more context or requirements. The task id can be inferred from the branch name, which follows `author/task_id/description` as defined in `scripts/hooks/commit-msg`. Corporate VPN must be on to access Linear; if task info fetch fails, mention VPN connectivity as a likely cause.
- **Committing**: The task id is appended automatically by `scripts/hooks/commit-msg`, so do not add it manually to commit messages.
- **TON domain questions**: Use `.codex/skills/tondocs/SKILL.md` to look up TON-specific concepts or documentation.
- **Skill readiness**: Check the skill’s README for its dependency/environment verification step and run it before using the skill. If the check fails, explain the failure reason and continue without the skill.

## Path Safety
- **No hardcoded absolute paths**: Avoid absolute paths in scripts or source; prefer repo-relative paths, environment overrides, or lazy clones in case of remote repositories. 
