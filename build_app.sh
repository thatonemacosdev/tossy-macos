#!/bin/bash
# Builds EasyConvert in release mode and packages it as a double-clickable .app bundle.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
APP_NAME="EasyConvert"
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
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done. Launch with: open ${APP_BUNDLE}"
