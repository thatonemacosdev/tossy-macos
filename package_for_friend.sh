#!/bin/bash
# ================================================================
#   TOSSY 2.0.0 - PORTABLE PACKAGER FOR FRIENDS & USERS
# ================================================================
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
APP_NAME="Tossy"
DISPLAY_NAME="Tossy"
BUNDLE_NAME="Tossy.app"
VERSION="2.0.0"

DIST_DIR="./dist"
STAGING_APP="${DIST_DIR}/${BUNDLE_NAME}"
ZIP_OUTPUT="${DIST_DIR}/Tossy-${VERSION}-macOS.zip"
DESKTOP_DIR="${HOME}/Desktop"

if [ -z "${SDKROOT:-}" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

echo "================================================================"
echo "          PACKAGING TOSSY 2.0.0 FOR DISTRIBUTION                "
echo "================================================================"

echo "1/5 Building native optimized binary (${CONFIG})..."
swift build -c "${CONFIG}"

echo "2/5 Assembling application bundle: ${STAGING_APP}..."
rm -rf "${STAGING_APP}"
mkdir -p "${STAGING_APP}/Contents/MacOS"
mkdir -p "${STAGING_APP}/Contents/Resources"

cp ".build/${CONFIG}/${APP_NAME}" "${STAGING_APP}/Contents/MacOS/${APP_NAME}"
cp "AppIcon.icns" "${STAGING_APP}/Contents/Resources/AppIcon.icns"
cp "icons/icon_128.png" "${STAGING_APP}/Contents/Resources/TossyLogo.png"
cp "Info.plist" "${STAGING_APP}/Contents/Info.plist"

echo "3/5 Bundling media & transcode engines (ffmpeg, webp, jxl)..."
mkdir -p "${STAGING_APP}/Contents/Resources/ffmpeg"
cp -R Vendor/ffmpeg/ffmpeg Vendor/ffmpeg/ffprobe Vendor/ffmpeg/libs "${STAGING_APP}/Contents/Resources/ffmpeg/"

mkdir -p "${STAGING_APP}/Contents/Resources/webp"
cp -R Vendor/webp/cwebp Vendor/webp/dwebp Vendor/webp/img2webp Vendor/webp/libs "${STAGING_APP}/Contents/Resources/webp/"

mkdir -p "${STAGING_APP}/Contents/Resources/jxl"
cp -R Vendor/jxl/cjxl Vendor/jxl/djxl Vendor/jxl/libs "${STAGING_APP}/Contents/Resources/jxl/"

echo "4/5 Stripping quarantine flags and code-signing bundle..."
xattr -cr "${STAGING_APP}" 2>/dev/null || true
find "${STAGING_APP}/Contents/Resources" -name "*.dylib" -exec codesign --force --sign - {} +
codesign --force --sign - "${STAGING_APP}/Contents/Resources/ffmpeg/ffmpeg"
codesign --force --sign - "${STAGING_APP}/Contents/Resources/ffmpeg/ffprobe"
codesign --force --sign - "${STAGING_APP}/Contents/Resources/webp/cwebp"
codesign --force --sign - "${STAGING_APP}/Contents/Resources/webp/dwebp"
codesign --force --sign - "${STAGING_APP}/Contents/Resources/webp/img2webp"
codesign --force --sign - "${STAGING_APP}/Contents/Resources/jxl/cjxl"
codesign --force --sign - "${STAGING_APP}/Contents/Resources/jxl/djxl"
codesign --force --sign - "${STAGING_APP}/Contents/MacOS/${APP_NAME}"
codesign --force --deep --sign - "${STAGING_APP}"

codesign --verify --deep --strict "${STAGING_APP}"

echo "5/5 Building clean distribution ZIP archive..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${STAGING_APP}" "${ZIP_OUTPUT}"
echo "  Packaged ZIP: ${ZIP_OUTPUT} ($(du -sh "${ZIP_OUTPUT}" | cut -f1))"

if [ -d "${DESKTOP_DIR}" ]; then
    cp "${ZIP_OUTPUT}" "${DESKTOP_DIR}/"
    echo "  Copied package to Desktop: ${DESKTOP_DIR}"
fi

echo ""
echo "================================================================"
echo "          PACKAGING COMPLETE - READY FOR DISTRIBUTION           "
echo "================================================================"
echo "ZIP Archive:   ${ZIP_OUTPUT}"
if [ -d "${DESKTOP_DIR}" ]; then
    echo "Desktop Copy:  ${DESKTOP_DIR}/Tossy-${VERSION}-macOS.zip"
fi
echo "================================================================"
