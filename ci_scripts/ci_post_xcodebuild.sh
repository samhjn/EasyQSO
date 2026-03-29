#!/bin/bash
set -e

echo "=== ci_post_xcodebuild: Start ==="

if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
    echo "Archive completed successfully."
    echo "  Product:  $CI_PRODUCT"
    echo "  Branch:   $CI_BRANCH"
    echo "  Commit:   $CI_COMMIT"
    echo "  Build #:  $CI_BUILD_NUMBER"
fi

echo "=== ci_post_xcodebuild: Done ==="
