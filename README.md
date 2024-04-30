# Tonkeeper iOS

## Setup

### Tonkeeper team

#### Build

- run `setup_keys.sh` script. it downloads Debug/Release GoogleService-Info.plist from [https://github.com/tonkeeper/ios_keys](https://github.com/tonkeeper/ios_keys)

#### Device debug

- download certificates and provisioning profiles from Apple Developer Portal.

### Contest

#### Build
- create you own GoogleService-Info.plist ([Steps 1-3](https://firebase.google.com/docs/ios/setup))
- put created GoogleService-Info.plist `/Tonkeeper/Resources/Firebase/Debug/`

#### Device debug

all signing related stuff located in xcconfig files.

- PRODUCT_BUNDLE_IDENTIFIER in Debug.xcconfig, WidgetDebug.xcconfig and IntentsDebug.xcconfig
- DEVELOPMENT_TEAM, CODE_SIGN_IDENTITY, PROVISIONING_PROFILE_SPECIFIER, WIDGET_CODE_SIGN_IDENTITY, WIDGET_PROVISIONING_PROFILE_SPECIFIER, INTENTS_CODE_SIGN_IDENTITY and INTENTS_CODE_SIGN_IDENTITY in SignDebug.xcconfig
