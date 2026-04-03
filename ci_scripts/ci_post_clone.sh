#!/bin/bash
set -e

echo "=== ci_post_clone: Start ==="

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-.}"

# Install XcodeGen to generate .xcodeproj from project.yml
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project with XcodeGen..."
cd "$REPO_ROOT"
xcodegen generate

# Log available simulator runtimes for CI debugging.
# Note: To test on iOS 15, configure the Xcode Cloud workflow to use
# Xcode 15.x which bundles the iOS 15 simulator runtime.
if [[ "$CI" == "TRUE" ]]; then
    echo "Available simulator runtimes:"
    xcrun simctl list runtimes
fi

echo "=== ci_post_clone: Done ==="
