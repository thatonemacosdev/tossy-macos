#!/bin/bash
# Builds Tossy v2.0.0 in Release Mode and installs to /Applications as Tossy.app
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
APP_NAME="Tossy"
INSTALL_NAME="Tossy"
TARGET_APP="/Applications/${INSTALL_NAME}.app"
USER_APP="${HOME}/Applications/${INSTALL_NAME}.app"
BUILD_DIR=".build/${CONFIG}"
STAGING_DIR="./dist/${INSTALL_NAME}.app"
ZIP_OUTPUT="./dist/Tossy-2.0.0-macOS.zip"

echo "================================================================"
echo "          BUILDING AND INSTALLING TOSSY V2.0.0                  "
echo "================================================================"

echo "0/7 Terminating any running Tossy instances..."
killall Tossy 2>/dev/null || true
sleep 0.5

if [ -z "${SDKROOT:-}" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

echo "1/7 Building native binary in ${CONFIG} mode..."
swift build -c "${CONFIG}"

echo "2/7 Assembling application bundle: ${STAGING_DIR}..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/Contents/MacOS"
mkdir -p "${STAGING_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${STAGING_DIR}/Contents/MacOS/${APP_NAME}"
cp "AppIcon.icns" "${STAGING_DIR}/Contents/Resources/AppIcon.icns"
cp "icons/icon_128.png" "${STAGING_DIR}/Contents/Resources/TossyLogo.png"

# Copy complete Info.plist with system services and registered url schemes
cp "Info.plist" "${STAGING_DIR}/Contents/Info.plist"

echo "3/7 Bundling vendored engines (ffmpeg, webp, jxl)..."
mkdir -p "${STAGING_DIR}/Contents/Resources/ffmpeg"
cp -R Vendor/ffmpeg/ffmpeg Vendor/ffmpeg/ffprobe Vendor/ffmpeg/libs "${STAGING_DIR}/Contents/Resources/ffmpeg/"

mkdir -p "${STAGING_DIR}/Contents/Resources/webp"
cp -R Vendor/webp/cwebp Vendor/webp/dwebp Vendor/webp/img2webp Vendor/webp/libs "${STAGING_DIR}/Contents/Resources/webp/"

mkdir -p "${STAGING_DIR}/Contents/Resources/jxl"
cp -R Vendor/jxl/cjxl Vendor/jxl/djxl Vendor/jxl/libs "${STAGING_DIR}/Contents/Resources/jxl/"

echo "4/7 Code-signing binaries and bundle..."
xattr -cr "${STAGING_DIR}" 2>/dev/null || true
find "${STAGING_DIR}/Contents/Resources" -name "*.dylib" -exec codesign --force --sign - {} +
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/ffmpeg/ffmpeg"
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/ffmpeg/ffprobe"
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/webp/cwebp"
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/webp/dwebp"
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/webp/img2webp"
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/jxl/cjxl"
codesign --force --sign - "${STAGING_DIR}/Contents/Resources/jxl/djxl"
codesign --force --sign - "${STAGING_DIR}/Contents/MacOS/${APP_NAME}"
codesign --force --deep --sign - "${STAGING_DIR}"

echo "5/7 Verifying signature..."
codesign --verify --deep --strict "${STAGING_DIR}"

echo "6/7 Packaging full release ZIP archive: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${STAGING_DIR}" "${ZIP_OUTPUT}"
echo "Packaged full release archive ($(du -sh "${ZIP_OUTPUT}" | cut -f1))"

echo "7/7 Installing to /Applications..."
if rm -rf "${TARGET_APP}" 2>/dev/null && cp -R "${STAGING_DIR}" "${TARGET_APP}" 2>/dev/null; then
    echo "Successfully installed Tossy to: ${TARGET_APP}"
else
    echo "Installing to user application directory: ${USER_APP}"
    mkdir -p "${HOME}/Applications"
    rm -rf "${USER_APP}"
    cp -R "${STAGING_DIR}" "${USER_APP}"
    echo "Successfully installed Tossy to: ${USER_APP}"
fi

echo "Launching Tossy..."
open "${TARGET_APP}" 2>/dev/null || open "${USER_APP}" 2>/dev/null || true

echo ""
echo "================================================================"
echo "          INSTALLATION COMPLETE: Tossy.app                      "
echo "================================================================"
