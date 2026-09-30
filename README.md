# Tonkeeper iOS

This directory is the iOS app; every command below runs from `ios/` (`cd ios`, or `make -C ios <target>` from the repository root).

## Setup

```sh
# installs the pinned dev tools (mise.toml), downloads Debug/Release
# GoogleService-Info.plist from https://github.com/tonkeeper/ios_keys
# and sets up git hooks.
make setup
```

## Tools

`mise.toml` pins the exact versions of swiftformat, swiftgen, swiftlint and xcbeautify;
`make setup` installs them (and installs [mise](https://mise.jdx.dev) itself through
Homebrew if it is missing). Nothing depends on your `PATH`: the make targets and the git
hooks resolve each tool through `scripts/tools/tool.sh`.

To bump a version, edit `mise.toml` and rerun `make setup`. Activating mise in your own
shell is optional — do it if you also want to type `swiftformat` directly:

```sh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
```

## Branches and commits

- Branch names must follow `author/TASK/description` (e.g., `rzm/IOS-562/fix-header`) where `TASK` is uppercase letters + digits.
- The `scripts/hooks/commit-msg` hook prefixes commit summaries with `[TASK]`, so do not add the task id manually. It also formats staged Swift files with the pinned swiftformat and rejects the commit if anything changed.

## Environment

If you use Codex skills, ensure required environment values and dependencies are configured first. 
Create a `.env` file at the repository root (one level above `ios/`) with:
- a non-empty `LINEAR_API_KEY` for the Linear skill. (see https://linear.app/developers)
- install `gh` (`brew install gh`) and call `gh auth login` for `tondocs` and `pr` skill
