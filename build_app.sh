#!/bin/bash
# Builds Tossy in release mode and packages it as a double-clickable .app bundle.
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

echo "Re-signing bundled binaries and app…"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/ffmpeg/ffmpeg"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/ffmpeg/ffprobe"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/webp/cwebp"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/webp/dwebp"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/webp/img2webp"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/jxl/cjxl"
codesign --force --sign - "${APP_BUNDLE}/Contents/Resources/jxl/djxl"
echo "Done. Launch with: open ${APP_BUNDLE}"

mkdir -p dist
rm -rf dist/Tossy.app dist/Tossy-1.4.0-macOS.zip
cp -R "${APP_BUNDLE}" dist/Tossy.app
(cd dist && zip -r -q -y Tossy-1.4.0-macOS.zip Tossy.app)
echo "Packaged dist/Tossy-1.4.0-macOS.zip"

