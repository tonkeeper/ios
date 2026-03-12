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

## Key Decisions
- **Worktrees**: Always perform refactoring or new feature work in a dedicated git worktree located under `worktrees/` directory in the repository root to maintain a clean environment and avoid permission issues.

## Skills Usage
- **Task context**: Use `.codex/skills/linear/SKILL.md` to fetch task details when you need more context or requirements. The task id can be inferred from the branch name, which follows `author/task_id/description` as defined in `scripts/hooks/commit-msg`. Corporate VPN must be on to access Linear; if task info fetch fails, mention VPN connectivity as a likely cause.
- **Committing**: The task id is appended automatically by `scripts/hooks/commit-msg`, so do not add it manually to commit messages.
- **TON domain questions**: Use `.codex/skills/tondocs/SKILL.md` to look up TON-specific concepts or documentation.
- **Skill readiness**: Check the skill’s README for its dependency/environment verification step and run it before using the skill. If the check fails, explain the failure reason and continue without the skill.

## Path Safety
- **No hardcoded absolute paths**: Avoid absolute paths in scripts or source; prefer repo-relative paths, environment overrides, or lazy clones in case of remote repositories. 
