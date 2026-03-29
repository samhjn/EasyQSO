#!/bin/bash
set -e

echo "=== ci_post_clone: Start ==="

# Install XcodeGen to generate .xcodeproj from project.yml
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project with XcodeGen..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "=== ci_post_clone: Done ==="
