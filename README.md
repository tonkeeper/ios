# Tonkeeper iOS

## Setup

```sh
# downloads Debug/Release GoogleService-Info.plist
# from https://github.com/tonkeeper/ios_keys
# and sets up git hooks.
make setup
```

#### Device debug

- download certificates and provisioning profiles from Apple Developer Portal.

#### Build
- create you own GoogleService-Info.plist ([Steps 1-3](https://firebase.google.com/docs/ios/setup))
- put created GoogleService-Info.plist `/Tonkeeper/Resources/Firebase/Debug/` and `/Tonkeeper/Resources/Firebase/Release/`

#### Device debug

all signing related stuff located in xcconfig files.

- PRODUCT_BUNDLE_IDENTIFIER in Debug.xcconfig, WidgetDebug.xcconfig and IntentsDebug.xcconfig
- DEVELOPMENT_TEAM, CODE_SIGN_IDENTITY, PROVISIONING_PROFILE_SPECIFIER, WIDGET_CODE_SIGN_IDENTITY, WIDGET_PROVISIONING_PROFILE_SPECIFIER, INTENTS_CODE_SIGN_IDENTITY and INTENTS_CODE_SIGN_IDENTITY in SignDebug.xcconfig

## Branches and commits

- Branch names must follow `author/TASK/description` (e.g., `rzm/IOS-562/fix-header`) where `TASK` is uppercase letters + digits.
- The `scripts/hooks/commit-msg` hook prefixes commit summaries with `[TASK]`, so do not add the task id manually.

## Environment

If you use Codex skills, ensure required environment values and dependencies are configured first. 
Create a repo-root `.env` file with:
- a non-empty `LINEAR_API_KEY` for the Linear skill. (see https://linear.app/developers)
- install `gh` (`brew install gh`) and call `gh auth login` for `tondocs` and `pr` skill

