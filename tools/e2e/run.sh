#!/bin/zsh
# Build Logos InkPen (Debug, automation probe compiled in) and drive it end-to-end with
# tools/e2e/InkPenE2E.swift. Exit code 0 = all checks passed.
# Needs Accessibility permission for the terminal/agent running this script.
set -e
ROOT="${0:A:h:h:h}"
DD="${INKPEN_E2E_DERIVED_DATA:-/tmp/logos-e2e-dd}"
cd "$ROOT"
if [[ -z "$INKPEN_E2E_SKIP_BUILD" ]]; then
  xcodebuild build -project "logos inkpen.io.xcodeproj" -scheme "logos inkpen.io" -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO -quiet
fi
swiftc -O -o "$DD/InkPenE2E" tools/e2e/InkPenE2E.swift
"$DD/InkPenE2E" "$DD/Build/Products/Debug/logos inkpen.io.app"
