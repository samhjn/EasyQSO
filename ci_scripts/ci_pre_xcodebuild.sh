#!/bin/bash
set -e

echo "=== ci_pre_xcodebuild: Start ==="

if [[ -z "$CI_BUILD_NUMBER" ]]; then
    echo "Not running in Xcode Cloud, skipping build number update."
    exit 0
fi

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-.}"
cd "$REPO_ROOT"

echo "Setting CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER ..."
agvtool new-version -all "$CI_BUILD_NUMBER"

if [[ -n "$CI_TAG" ]]; then
    VERSION="${CI_TAG#v}"
    echo "Tag detected, setting MARKETING_VERSION to $VERSION ..."
    agvtool new-marketing-version "$VERSION"
fi

echo "=== ci_pre_xcodebuild: Done ==="
