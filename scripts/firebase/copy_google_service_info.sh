#!/bin/sh
set -eu

INFO_PLIST_NAME="GoogleService-Info.plist"
FIREBASE_ROOT="${PROJECT_DIR}/${TARGET_NAME}/Resources/Firebase"

FOLDER="Tonkeeper"
case "${CONFIGURATION}" in
  TonkeeperDevDebug|TonkeeperDevRelease)
    FOLDER="TonkeeperDev"
    ;;
  TonkeeperXDebug)
    FOLDER="TonkeeperXDebug"
    ;;
  TonkeeperXRelease)
    FOLDER="TonkeeperXRelease"
    ;;
  TonkeeperUKDebug|TonkeeperUKRelease)
    FOLDER="TonkeeperUK"
    ;;
esac

SOURCE_PLIST="${FIREBASE_ROOT}/${FOLDER}/${INFO_PLIST_NAME}"
DEFAULT_PLIST="${FIREBASE_ROOT}/Tonkeeper/${INFO_PLIST_NAME}"
DESTINATION_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
DESTINATION_PLIST="${DESTINATION_DIR}/${INFO_PLIST_NAME}"

if [ ! -f "${SOURCE_PLIST}" ]; then
  if [ "${FOLDER}" = "TonkeeperUK" ] && [ -f "${DEFAULT_PLIST}" ]; then
    echo "Firebase plist for ${FOLDER} is missing, fallback to Tonkeeper"
    SOURCE_PLIST="${DEFAULT_PLIST}"
  else
    echo "Firebase plist not found: ${SOURCE_PLIST}" >&2
    exit 1
  fi
fi

mkdir -p "${DESTINATION_DIR}"
cp "${SOURCE_PLIST}" "${DESTINATION_PLIST}"
echo "Copied ${SOURCE_PLIST} -> ${DESTINATION_PLIST}"
