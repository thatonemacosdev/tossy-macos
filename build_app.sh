#!/bin/bash
# Builds Tossy in release mode and packages it as a double-clickable .app bundle,
# compressed .dmg installer (with /Applications symlink), and clean .zip archive.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
APP_NAME="Tossy"
BUILD_DIR=".build/${CONFIG}"
APP_BUNDLE="./${APP_NAME}.app"

echo "Building ${APP_NAME} (${CONFIG})…"
swift build -c "${CONFIG}"

echo "Packaging ${APP_BUNDLE}…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "icons/icon_128.png" "${APP_BUNDLE}/Contents/Resources/TossyLogo.png"

echo "Bundling ffmpeg/ffprobe…"
mkdir -p "${APP_BUNDLE}/Contents/Resources/ffmpeg"
cp -R Vendor/ffmpeg/ffmpeg Vendor/ffmpeg/ffprobe Vendor/ffmpeg/libs "${APP_BUNDLE}/Contents/Resources/ffmpeg/"

echo "Bundling cwebp/dwebp/img2webp…"
mkdir -p "${APP_BUNDLE}/Contents/Resources/webp"
cp -R Vendor/webp/cwebp Vendor/webp/dwebp Vendor/webp/img2webp Vendor/webp/libs "${APP_BUNDLE}/Contents/Resources/webp/"

echo "Bundling cjxl/djxl…"
mkdir -p "${APP_BUNDLE}/Contents/Resources/jxl"
cp -R Vendor/jxl/cjxl Vendor/jxl/djxl Vendor/jxl/libs "${APP_BUNDLE}/Contents/Resources/jxl/"

echo "Stripping quarantine and extended attributes…"
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

echo "Re-signing bundled binaries, libraries, and app bundle…"
find "${APP_BUNDLE}/Contents/Resources" -name "*.dylib" -exec codesign --force --sign - {} +
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/ffmpeg/ffmpeg"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/ffmpeg/ffprobe"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/webp/cwebp"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/webp/dwebp"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/webp/img2webp"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/jxl/cjxl"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/jxl/djxl"
codesign --force --sign - "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Verifying code signature…"
codesign --verify --deep --strict "${APP_BUNDLE}"

mkdir -p dist
rm -rf dist/Tossy.app dist/Tossy-*.zip dist/Tossy-*.dmg dist/dmg_staging
cp -R "${APP_BUNDLE}" dist/Tossy.app

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "Info.plist" 2>/dev/null || echo "1.6.2")

echo "Packaging clean distribution zip with ditto (v${VERSION})…"
ditto -c -k --keepParent "dist/Tossy.app" "dist/Tossy-${VERSION}-macOS.zip"
echo "Packaged dist/Tossy-${VERSION}-macOS.zip"

echo "Packaging clean distribution DMG with hdiutil (v${VERSION})…"
DMG_STAGING="dist/dmg_staging"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/Tossy.app"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "Tossy" -srcfolder "${DMG_STAGING}" -ov -format UDZO "dist/Tossy-${VERSION}-macOS.dmg"
codesign --force --sign - "dist/Tossy-${VERSION}-macOS.dmg"
rm -rf "${DMG_STAGING}"
echo "Packaged dist/Tossy-${VERSION}-macOS.dmg"
