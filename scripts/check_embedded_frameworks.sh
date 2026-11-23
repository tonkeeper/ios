#!/bin/sh
# Fails if the app embeds a framework outside the linking contract (AGENTS.md "Linking"):
# each extra framework is one more image that dyld loads at every launch.
set -eu

app="$1"
allowed=" AppsFlyerLib ChainKit CryptoSwift FirebaseAnalytics GoogleAppMeasurement KeeperCore TKBase TKUIKit WalletCore WalletCoreSwiftProtobuf "

unexpected=""
for framework in "$app"/Frameworks/*.framework; do
    name=$(basename "$framework" .framework | sed -E 's/_[0-9A-F]+_PackageProduct$//')
    case "$allowed" in
        *" $name "*) ;;
        *) unexpected="$unexpected $name" ;;
    esac
done

if [ -n "$unexpected" ]; then
    echo "error: unexpected embedded frameworks:$unexpected" >&2
    echo "A package product declared by more than one linking target becomes its own framework." >&2
    echo "Import it through KeeperCore, TKUIKit or TKBase instead (AGENTS.md \"Linking\")." >&2
    exit 1
fi
