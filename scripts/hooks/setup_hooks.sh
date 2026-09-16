#!/bin/sh
set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
GIT_DIR="$( cd $(git rev-parse --git-common-dir) && pwd )"

cp -f "${SCRIPT_DIR}/commit-msg" "${GIT_DIR}/hooks/commit-msg"
chmod +x "${GIT_DIR}/hooks/commit-msg"

cp -f "${SCRIPT_DIR}/post-checkout" "${GIT_DIR}/hooks/post-checkout"
chmod +x "${GIT_DIR}/hooks/post-checkout"
