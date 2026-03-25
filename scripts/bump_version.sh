#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="Configurations/common.xcconfig"
KEY="APP_VERSION_COMMON"

# current YY and MM from one date call to avoid boundary race
read -r CUR_YY CUR_MM <<< "$(date +'%y %m')" # 26 02

# read line APP_VERSION_COMMON = ...
LINE=$(grep "^${KEY} *=" "$CONFIG_FILE")

# extract current version 26.02.1
CURRENT_VERSION=$(echo "$LINE" | sed -E 's/^[^=]*= *([0-9]{2}\.[0-9]{2}\.[0-9]+)/\1/')
CUR_V_YY=$(echo "$CURRENT_VERSION" | cut -d'.' -f1)
CUR_V_MM=$(echo "$CURRENT_VERSION" | cut -d'.' -f2)
CUR_V_N=$(echo "$CURRENT_VERSION" | cut -d'.' -f3)

if [[ "$CUR_YY" == "$CUR_V_YY" && "$CUR_MM" == "$CUR_V_MM" ]]; then
  # year and month are current, just bump iteration
  NEW_N=$((CUR_V_N + 1))
else
  # new month/year, start interation from 0
  NEW_N=0
fi

NEW_VERSION="${CUR_YY}.${CUR_MM}.${NEW_N}"

echo "Current version: $CURRENT_VERSION"
echo "New version:     $NEW_VERSION"

# Update config file
sed -i'' -E "s#^${KEY} *= *[0-9]{2}\.[0-9]{2}\.[0-9]+#${KEY} = ${NEW_VERSION}#" "$CONFIG_FILE"
