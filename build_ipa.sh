#!/bin/bash

# Configuration
# Use absolute path for PWD to avoid relative path issues
PROJECT_ROOT="$(pwd)"
PROJECT_NAME="EasyQSO"
SCHEME_NAME="EasyQSO"
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

# 0. Run Tests
echo "🧪 Running tests..."
# Auto-detect an available iPhone simulator
SIM_DEVICE=$(xcrun simctl list devices available -j \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime: continue
    for d in devices:
        if 'iPhone' in d['name'] and d['isAvailable']:
            print(d['name']); sys.exit(0)
" 2>/dev/null)

if [ -z "$SIM_DEVICE" ]; then
    echo "⚠️  No available iPhone simulator found, skipping tests."
else
    echo "   Using simulator: ${SIM_DEVICE}"
    xcodebuild test \
      -project "${PROJECT_NAME}.xcodeproj" \
      -scheme "${SCHEME_NAME}" \
      -destination "platform=iOS Simulator,name=${SIM_DEVICE}" \
      -resultBundlePath "${BUILD_DIR}/TestResults.xcresult" \
      -quiet

    if [ $? -ne 0 ]; then
        echo "❌ Tests failed. Aborting build."
        exit 1
    fi
    echo "✅ All tests passed."
fi

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
