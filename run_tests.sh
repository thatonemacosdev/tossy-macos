#!/bin/bash
# Complete Test Suite Runner for Tossy v2.0 Beta
set -euo pipefail

cd "$(dirname "$0")"

if [ -z "${SDKROOT:-}" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

echo "================================================================"
echo "          TOSSY TEST SUITE - FULL END-TO-END RUNNER             "
echo "================================================================"

mkdir -p build_sandbox/tests

echo "1/6 Compiling PDF Studio Test Suite..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_pdf_studio.swift -o build_sandbox/tests/test_pdf_studio_bin

echo "2/6 Compiling Media Studio Test Suite..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_media_studio.swift -o build_sandbox/tests/test_media_studio_bin

echo "3/6 Compiling Archive Suite Test Suite..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_archive_studio.swift -o build_sandbox/tests/test_archive_studio_bin

echo "4/6 Compiling Automation Suite Test Suite..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_automation_studio.swift -o build_sandbox/tests/test_automation_studio_bin

echo "5/6 Compiling QA Fixes & Safeguards Test Suite..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_qa_bugs_only.swift -o build_sandbox/tests/test_qa_bugs_only_bin

echo "6/6 Compiling V2 Polish Tasks Test Suite..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_v2_polish_tasks.swift -o build_sandbox/tests/test_v2_polish_tasks_bin

echo ""
echo "================================================================"
echo "               EXECUTING ALL 6 TEST SUITES                      "
echo "================================================================"

echo ""
echo ">>> Running Pillar 1: PDF & Document Studio Tests..."
./build_sandbox/tests/test_pdf_studio_bin

echo ""
echo ">>> Running Pillar 2: Media Studio Tools Tests..."
./build_sandbox/tests/test_media_studio_bin

echo ""
echo ">>> Running Pillar 3: Archive & Compression Tests..."
./build_sandbox/tests/test_archive_studio_bin

echo ""
echo ">>> Running Pillar 4: Automation & Ingestion Tests..."
./build_sandbox/tests/test_automation_studio_bin

echo ""
echo ">>> Running Targeted QA Bug Fixes Tests..."
./build_sandbox/tests/test_qa_bugs_only_bin

echo ""
echo ">>> Running V2 Polish Tasks Tests..."
./build_sandbox/tests/test_v2_polish_tasks_bin

echo ""
echo "================================================================"
echo "              GLOBAL TEST RESULT: 100% SUCCESS                  "
echo "================================================================"
