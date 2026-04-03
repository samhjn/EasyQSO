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

if [[ "$CI_XCODEBUILD_ACTION" == "test-without-building" || "$CI_XCODEBUILD_ACTION" == "test" ]]; then
    echo "Tests completed."
    echo "  Product:     $CI_PRODUCT"
    echo "  Branch:      $CI_BRANCH"
    echo "  Commit:      $CI_COMMIT"
    echo "  Build #:     $CI_BUILD_NUMBER"
    echo "  Destination: $CI_TEST_DESTINATION_RUNTIME"
    echo "  Device:      $CI_TEST_DESTINATION_DEVICE_TYPE"
    echo "  Exit code:   $CI_XCODEBUILD_EXIT_CODE"
fi

echo "=== ci_post_xcodebuild: Done ==="
