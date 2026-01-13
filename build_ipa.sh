#!/bin/bash

# Configuration
# Use absolute path for PWD to avoid relative path issues
PROJECT_ROOT="$(pwd)"
PROJECT_NAME="HamRadioLogger"
SCHEME_NAME="HamRadioLogger"
BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/Export"
IPA_PATH="${EXPORT_DIR}/${SCHEME_NAME}.ipa"

# Ensure script is run from the project root
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Project file not found. Please run this script from the project root directory."
    exit 1
fi

# Clean build directory
echo "🧹 Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${EXPORT_DIR}"

echo "🚀 Starting build for ${PROJECT_NAME}..."

# 1. Archive
echo "📦 Archiving..."
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  -destination 'generic/platform=iOS' \
  -quiet

if [ $? -ne 0 ]; then
    echo "❌ Archive failed."
    exit 1
fi

# 2. Manual Package
echo "🛠  Manually packaging IPA..."

# Find the .app with absolute path resolution
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: App bundle not found at: ${APP_PATH}"
    # Try finding it dynamically if exact path fails
    APP_PATH=$(find "${ARCHIVE_PATH}/Products/Applications" -name "*.app" | head -n 1)
    if [ ! -d "${APP_PATH}" ]; then
         echo "❌ Critical: Could not locate .app in archive."
         exit 1
    fi
fi

echo "   Found App: ${APP_PATH}"

# Prepare Payload in Export directory
# We stay in PROJECT_ROOT to manage paths clearly, or cd only for zip
mkdir -p "${EXPORT_DIR}/Payload"
cp -R "${APP_PATH}" "${EXPORT_DIR}/Payload/"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to copy app to Payload directory."
    exit 1
fi

# Zip
echo "🤐 Zipping..."
cd "${EXPORT_DIR}"
# -r recursive, -q quiet
zip -r -q "${SCHEME_NAME}.ipa" Payload
cd "${PROJECT_ROOT}"

# Cleanup
rm -rf "${EXPORT_DIR}/Payload"

echo "✅ Build successful!"
echo "📁 IPA location: ${IPA_PATH}"
open "${EXPORT_DIR}"
