#!/bin/bash
# Standalone Verification Runner for GitHub Issue #1 (Audio-Only WebM Transcoding)
set -euo pipefail

cd "$(dirname "$0")"

echo "================================================================"
echo "          TOSSY ISSUE #1 VERIFICATION RUNNER                    "
echo "================================================================"

mkdir -p build_sandbox/tests
mkdir -p test_samples

# Ensure sample WebM file exists
if [ ! -f "test_samples/sample_issue1_opus.webm" ]; then
    echo "Generating test audio-only WebM sample in test_samples/..."
    ./Vendor/ffmpeg/ffmpeg -y -nostdin -f lavfi -i "sine=frequency=440:duration=3" -c:a libopus -b:a 128k -vn test_samples/sample_issue1_opus.webm > /dev/null 2>&1
fi

if [ -z "${SDKROOT:-}" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

echo "Compiling Issue #1 Test Binary..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_issue1.swift -o build_sandbox/tests/test_issue1_bin

echo ""
echo "Running Issue #1 Verification Suite..."
./build_sandbox/tests/test_issue1_bin

# Clean up binary
rm -f build_sandbox/tests/test_issue1_bin
