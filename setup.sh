#!/bin/bash
set -e

echo "==> Checking for xcodegen..."
if ! command -v xcodegen &> /dev/null; then
    echo "==> Installing xcodegen (requires Homebrew)..."
    brew install xcodegen
fi

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Opening Xcode project..."
open NextMeeting.xcodeproj

echo ""
echo "Build steps:"
echo "  1. Xcode > Signing & Capabilities > select your Apple ID team"
echo "  2. Press Command+R to run"
echo "  3. Grant calendar access when prompted"
