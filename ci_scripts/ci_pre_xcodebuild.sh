#!/bin/bash
set -e

echo "=== ci_pre_xcodebuild: Start ==="

if [[ -z "$CI_BUILD_NUMBER" ]]; then
    echo "Not running in Xcode Cloud, skipping build number update."
    exit 0
fi

PLIST_PATH="$CI_PRIMARY_REPOSITORY_PATH/EasyQSO/Info.plist"

echo "Setting CFBundleVersion to $CI_BUILD_NUMBER ..."
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$PLIST_PATH"

if [[ -n "$CI_TAG" ]]; then
    VERSION="${CI_TAG#v}"
    echo "Tag detected, setting CFBundleShortVersionString to $VERSION ..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST_PATH"
fi

echo "=== ci_pre_xcodebuild: Done ==="
