#!/usr/bin/env bash
set -euo pipefail

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

mkdir -p test_reports

"${FLUTTER_BIN}" analyze
"${FLUTTER_BIN}" test --coverage --machine > test_reports/flutter-tests.json

echo "Flutter tests OK."
echo "Machine report: test_reports/flutter-tests.json"
echo "Coverage report: coverage/lcov.info"
