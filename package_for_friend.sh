#!/bin/bash
# ================================================================
#   TOSSY 2 BETA - PORTABLE PACKAGER FOR FRIENDS & BETA TESTERS
# ================================================================
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
APP_NAME="Tossy"
DISPLAY_NAME="Tossy 2 Beta"
BUNDLE_NAME="Tossy-2-beta.app"
VERSION="2.0.0-beta"

DIST_DIR="./dist"
STAGING_APP="${DIST_DIR}/${BUNDLE_NAME}"
DMG_OUTPUT="${DIST_DIR}/Tossy-2-beta-Installer.dmg"
ZIP_OUTPUT="${DIST_DIR}/Tossy-2-beta-macOS.zip"
DESKTOP_DIR="${HOME}/Desktop"

echo "================================================================"
echo "          PACKAGING TOSSY 2 BETA FOR DISTRIBUTION               "
echo "================================================================"

echo "1/7 Building native optimized binary (${CONFIG})..."
swift build -c "${CONFIG}"

echo "2/7 Assembling application bundle: ${STAGING_APP}..."
rm -rf "${STAGING_APP}"
mkdir -p "${STAGING_APP}/Contents/MacOS"
mkdir -p "${STAGING_APP}/Contents/Resources"

cp ".build/${CONFIG}/${APP_NAME}" "${STAGING_APP}/Contents/MacOS/${APP_NAME}"
cp "AppIcon.icns" "${STAGING_APP}/Contents/Resources/AppIcon.icns"
cp "icons/icon_128.png" "${STAGING_APP}/Contents/Resources/TossyLogo.png"

# Generate complete Info.plist
cat << EOF > "${STAGING_APP}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.thatonemacosdev.tossy2beta</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright (c) 2026 ThatOneMacOSDev. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "3/7 Bundling media & transcode engines (ffmpeg, webp, jxl)..."
mkdir -p "${STAGING_APP}/Contents/Resources/ffmpeg"
cp -R Vendor/ffmpeg/ffmpeg Vendor/ffmpeg/ffprobe Vendor/ffmpeg/libs "${STAGING_APP}/Contents/Resources/ffmpeg/"

mkdir -p "${STAGING_APP}/Contents/Resources/webp"
cp -R Vendor/webp/cwebp Vendor/webp/dwebp Vendor/webp/img2webp Vendor/webp/libs "${STAGING_APP}/Contents/Resources/webp/"

mkdir -p "${STAGING_APP}/Contents/Resources/jxl"
cp -R Vendor/jxl/cjxl Vendor/jxl/djxl Vendor/jxl/libs "${STAGING_APP}/Contents/Resources/jxl/"

echo "4/7 Stripping quarantine flags and code-signing bundle..."
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

echo "5/7 Building clean distribution ZIP archive..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${STAGING_APP}" "${ZIP_OUTPUT}"
echo "  Packaged ZIP: ${ZIP_OUTPUT} ($(du -sh "${ZIP_OUTPUT}" | cut -f1))"

echo "6/7 Building Drag-and-Drop installer DMG..."
DMG_STAGING="${DIST_DIR}/dmg_staging"
rm -rf "${DMG_STAGING}" "${DMG_OUTPUT}"
mkdir -p "${DMG_STAGING}"

cp -R "${STAGING_APP}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "Tossy 2 Beta" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDZO \
    "${DMG_OUTPUT}"

rm -rf "${DMG_STAGING}"
echo "  Packaged DMG: ${DMG_OUTPUT} ($(du -sh "${DMG_OUTPUT}" | cut -f1))"

echo "7/7 Copying packages to Desktop for easy sharing..."
if [ -d "${DESKTOP_DIR}" ]; then
    cp "${DMG_OUTPUT}" "${DESKTOP_DIR}/"
    cp "${ZIP_OUTPUT}" "${DESKTOP_DIR}/"
    echo "  Copied packages to Desktop: ${DESKTOP_DIR}"
fi

echo ""
echo "================================================================"
echo "          PACKAGING COMPLETE - READY FOR YOUR FRIEND!           "
echo "================================================================"
echo "Installer DMG: ${DMG_OUTPUT}"
echo "ZIP Archive:   ${ZIP_OUTPUT}"
if [ -d "${DESKTOP_DIR}" ]; then
    echo "Desktop Copy:  ${DESKTOP_DIR}/Tossy-2-beta-Installer.dmg"
    echo "Desktop Copy:  ${DESKTOP_DIR}/Tossy-2-beta-macOS.zip"
fi
echo "================================================================"
