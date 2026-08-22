#!/bin/bash
# Standalone Fast Runner for QA Bug Fixes Suite ONLY
set -euo pipefail

cd "$(dirname "$0")"

echo "================================================================"
echo "          TOSSY QA BUG FIXES - STANDALONE RUNNER                "
echo "================================================================"

mkdir -p build_sandbox/tests

echo "Compiling QA Bug Fixes Test Binary..."
swiftc -parse-as-library $(find Sources/EasyConvert -name "*.swift" ! -name "EasyConvertApp.swift") build_sandbox/tests/test_qa_bugs_only.swift -o build_sandbox/tests/test_qa_bugs_only_bin

echo ""
echo "Running QA Bug Fixes Test Suite..."
./build_sandbox/tests/test_qa_bugs_only_bin
