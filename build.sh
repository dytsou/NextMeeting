#!/bin/bash
set -e

# Always use paths relative to this script (repo root), not the caller's cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="NextMeeting"
BUNDLE_ID="com.nextmeeting.app"
APP="${APP_NAME}.app"
SRC="NextMeeting"

# ── Check for Swift compiler ──────────────────────────────────────────────────
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found."
    echo "Install Xcode Command Line Tools and try again:"
    echo "  xcode-select --install"
    exit 1
fi

echo "==> Cleaning previous build..."
rm -rf "$APP"

echo "==> Creating .app bundle structure..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

echo "==> Compiling Swift sources..."
SDK=$(xcrun --show-sdk-path --sdk macosx)
ARCH=$(uname -m)

SWIFT_SRCS=(
    "$SRC/CalendarSelectionStore.swift"
    "$SRC/CalendarManager.swift"
    "$SRC/JoinPreferenceStore.swift"
    "$SRC/MeetingMenuView.swift"
    "$SRC/NextMeetingApp.swift"
)
for f in "${SWIFT_SRCS[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "Error: missing source file: $f" >&2
        echo "Pull the latest repo; JoinPreferenceStore.swift must exist next to the other Swift sources." >&2
        exit 1
    fi
done

swiftc \
    -sdk "$SDK" \
    -target "${ARCH}-apple-macos13.0" \
    -parse-as-library \
    -framework SwiftUI \
    -framework AppKit \
    -framework EventKit \
    -O \
    "${SWIFT_SRCS[@]}" \
    -o "$APP/Contents/MacOS/$APP_NAME"

echo "==> Copying resources..."

sed -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" \
    -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" \
    -e "s/\$(PRODUCT_NAME)/$APP_NAME/g" \
    -e "s/\$(DEVELOPMENT_LANGUAGE)/en/g" \
    "$SRC/Info.plist" > "$APP/Contents/Info.plist"

# Required by macOS for all .app bundles
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Localized strings
cp -r "$SRC/en.lproj"      "$APP/Contents/Resources/"
cp -r "$SRC/zh-Hant.lproj" "$APP/Contents/Resources/"

ASSET="$SRC/Assets.xcassets/AppIcon.appiconset"
if [[ -f "$ASSET/Contents.json" ]]; then
	echo "==> App icon: packing AppIcon.icns from Assets.xcassets..."
	WORK=$(mktemp -d)
	mkdir -p "$WORK/AppIcon.iconset"
	cp "$ASSET"/icon_*.png "$WORK/AppIcon.iconset/"
	iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
	rm -rf "$WORK"
else
	echo "Warning: missing $ASSET — restore NextMeeting/Assets.xcassets/AppIcon.appiconset from the repo."
fi

echo "==> Signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "$SRC/NextMeeting.entitlements" \
    "$APP"

echo ""
echo "Build complete: ./$APP"
echo ""

# ── Optional: install to /Applications ───────────────────────────────────────
read -r -p "Install to /Applications? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    cp -r "$APP" /Applications/
    echo "Installed. Launching..."
    open "/Applications/$APP_NAME.app"
else
    echo "To install manually:"
    echo "  cp -r $APP /Applications/"
    echo "  open /Applications/$APP_NAME.app"
fi
