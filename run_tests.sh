#!/bin/bash
# Complete Native SPM Test Suite Runner for Tossy v2.2
set -euo pipefail

cd "$(dirname "$0")"

echo "================================================================"
echo "          TOSSY TEST SUITE - FAST SPM RUNNER (v2.2)             "
echo "================================================================"

swift test

echo ""
echo "================================================================"
echo "              GLOBAL TEST RESULT: 100% SUCCESS                  "
echo "================================================================"
