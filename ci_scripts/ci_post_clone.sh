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

echo "=== ci_post_clone: Done ==="
