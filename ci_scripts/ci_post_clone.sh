#!/bin/bash
set -e

echo "=== ci_post_clone: Start ==="

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-.}"

# Install XcodeGen to generate .xcodeproj from project.yml
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
fi

# GitVersion.swift is gitignored; create a compilable placeholder so XcodeGen
# can include it in the source list. The real values are injected by the
# Xcode pre-build script at every build.
GIT_VERSION_FILE="$REPO_ROOT/EasyQSO/GitVersion.swift"
if [ ! -f "$GIT_VERSION_FILE" ]; then
    echo "Creating GitVersion.swift placeholder..."
    cat > "$GIT_VERSION_FILE" << 'PLACEHOLDER'
// Auto-generated placeholder. Will be overwritten by pre-build script.
enum GitVersion {
    static let commitHash = "unknown"
    static let isDirty = false
    static var isAvailable: Bool {
        commitHash != "unknown" && !commitHash.isEmpty
    }
    static var displayVersion: String {
        guard isAvailable else { return "unknown" }
        return isDirty ? "\(commitHash)-dirty" : commitHash
    }
}
PLACEHOLDER
fi

echo "Generating Xcode project with XcodeGen..."
cd "$REPO_ROOT"
xcodegen generate

echo "=== ci_post_clone: Done ==="
