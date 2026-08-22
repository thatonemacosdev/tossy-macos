#!/bin/bash
# Builds Tossy v2.0 Titanium in Release Mode and installs to /Applications as Tossy-2-alpha.app
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
APP_NAME="Tossy"
INSTALL_NAME="Tossy-2-alpha"
TARGET_APP="/Applications/${INSTALL_NAME}.app"
USER_APP="${HOME}/Applications/${INSTALL_NAME}.app"
BUILD_DIR=".build/${CONFIG}"
STAGING_DIR="./dist/${INSTALL_NAME}.app"

echo "================================================================"
echo "          BUILDING AND INSTALLING TOSSY V2.0 ALPHA              "
echo "================================================================"

echo "1/6 Building native binary in ${CONFIG} mode..."
swift build -c "${CONFIG}"

echo "2/6 Assembling application bundle: ${STAGING_DIR}..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/Contents/MacOS"
mkdir -p "${STAGING_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${STAGING_DIR}/Contents/MacOS/${APP_NAME}"
cp "AppIcon.icns" "${STAGING_DIR}/Contents/Resources/AppIcon.icns"
cp "icons/icon_128.png" "${STAGING_DIR}/Contents/Resources/TossyLogo.png"

# Generate Info.plist customized for Tossy 2 Alpha
cat << 'EOF' > "${STAGING_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Tossy</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.thatonemacosdev.tossy2alpha</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Tossy 2 Alpha</string>
    <key>CFBundleDisplayName</key>
    <string>Tossy 2 Alpha</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0-alpha</string>
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

echo "3/6 Bundling vendored engines (ffmpeg, webp, jxl)..."
mkdir -p "${STAGING_DIR}/Contents/Resources/ffmpeg"
cp -R Vendor/ffmpeg/ffmpeg Vendor/ffmpeg/ffprobe Vendor/ffmpeg/libs "${STAGING_DIR}/Contents/Resources/ffmpeg/"

mkdir -p "${STAGING_DIR}/Contents/Resources/webp"
cp -R Vendor/webp/cwebp Vendor/webp/dwebp Vendor/webp/img2webp Vendor/webp/libs "${STAGING_DIR}/Contents/Resources/webp/"

mkdir -p "${STAGING_DIR}/Contents/Resources/jxl"
cp -R Vendor/jxl/cjxl Vendor/jxl/djxl Vendor/jxl/libs "${STAGING_DIR}/Contents/Resources/jxl/"

echo "4/6 Code-signing binaries and bundle..."
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

echo "5/6 Verifying signature..."
codesign --verify --deep --strict "${STAGING_DIR}"

echo "6/6 Installing to /Applications..."
if rm -rf "${TARGET_APP}" 2>/dev/null && cp -R "${STAGING_DIR}" "${TARGET_APP}" 2>/dev/null; then
    echo "Successfully installed Tossy 2 Alpha to: ${TARGET_APP}"
else
    echo "Installing to user application directory: ${USER_APP}"
    mkdir -p "${HOME}/Applications"
    rm -rf "${USER_APP}"
    cp -R "${STAGING_DIR}" "${USER_APP}"
    echo "Successfully installed Tossy 2 Alpha to: ${USER_APP}"
fi

echo ""
echo "================================================================"
echo "          INSTALLATION COMPLETE: Tossy-2-alpha.app              "
echo "================================================================"
