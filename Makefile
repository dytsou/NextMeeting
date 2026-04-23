APP_NAME  := NextMeeting
BUNDLE_ID := com.nextmeeting.app
APP       := $(APP_NAME).app
SRC       := NextMeeting
INSTALL_DIR ?= /Applications

SDK       := $(shell xcrun --show-sdk-path --sdk macosx)
ARCH      := $(shell uname -m)
TARGET    := $(ARCH)-apple-macos13.0

SWIFT_SRCS := \
	$(SRC)/CalendarSelectionStore.swift \
	$(SRC)/CalendarManager.swift \
	$(SRC)/JoinPreferenceStore.swift \
	$(SRC)/AppearanceStore.swift \
	$(SRC)/AppDebug.swift \
	$(SRC)/MeetingMenuView.swift \
	$(SRC)/NextMeetingApp.swift \
	$(SRC)/String+HalfwidthPrefix.swift \
	$(SRC)/UpdateChecker.swift

.PHONY: all build sync-app-version setup clean install

all: build

## Sync CFBundleShortVersionString and CFBundleVersion from package.json into NextMeeting/Info.plist
sync-app-version:
	@bash scripts/sync-info-plist-version.sh

## Build the .app bundle
build: sync-app-version
	@echo "==> Cleaning previous build..."
	@rm -rf "$(APP)"
	@echo "==> Creating .app bundle structure..."
	@mkdir -p "$(APP)/Contents/MacOS"
	@mkdir -p "$(APP)/Contents/Resources"
	@echo "==> Compiling Swift sources..."
	swiftc \
		-sdk "$(SDK)" \
		-target "$(TARGET)" \
		-parse-as-library \
		-framework SwiftUI \
		-framework AppKit \
		-framework EventKit \
		-O \
		$(SWIFT_SRCS) \
		-o "$(APP)/Contents/MacOS/$(APP_NAME)"
	@echo "==> Copying resources..."
	@sed \
		-e "s/\$$(PRODUCT_BUNDLE_IDENTIFIER)/$(BUNDLE_ID)/g" \
		-e "s/\$$(EXECUTABLE_NAME)/$(APP_NAME)/g" \
		-e "s/\$$(PRODUCT_NAME)/$(APP_NAME)/g" \
		-e "s/\$$(DEVELOPMENT_LANGUAGE)/en/g" \
		"$(SRC)/Info.plist" > "$(APP)/Contents/Info.plist"
	@printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	@cp -r "$(SRC)/en.lproj"       "$(APP)/Contents/Resources/"
	@cp -r "$(SRC)/zh-Hant.lproj"  "$(APP)/Contents/Resources/"
	@echo "==> App icon: packing AppIcon.icns from Assets.xcassets..."
	@ASSET="$(SRC)/Assets.xcassets/AppIcon.appiconset"; \
	if [ -f "$$ASSET/Contents.json" ]; then \
		WORK=$$(mktemp -d); \
		mkdir -p "$$WORK/AppIcon.iconset"; \
		cp "$$ASSET"/icon_*.png "$$WORK/AppIcon.iconset/"; \
		if ! iconutil -c icns "$$WORK/AppIcon.iconset" -o "$(APP)/Contents/Resources/AppIcon.icns"; then \
			echo "Warning: failed to pack AppIcon.icns (iconutil). Continuing without custom icon."; \
		fi; \
		rm -rf "$$WORK"; \
	else \
		echo "Warning: missing $$ASSET — restore NextMeeting/Assets.xcassets/AppIcon.appiconset from the repo."; \
	fi
	@echo "==> Signing (ad-hoc)..."
	@tmp=$$(mktemp); \
	plutil -convert xml1 -o "$$tmp" "$(SRC)/NextMeeting.entitlements"; \
	codesign --force --deep --sign - --entitlements "$$tmp" "$(APP)"; \
	rm -f "$$tmp"
	@echo ""
	@echo "Build complete: ./$(APP)"

## Install to /Applications, kill any running instance, and relaunch
install: build
	@dest="$(INSTALL_DIR)"; \
	if [ ! -w "$$dest" ]; then \
		dest="$$HOME/Applications"; \
		mkdir -p "$$dest"; \
		echo "==> $(INSTALL_DIR) not writable; installing to $$dest instead."; \
	else \
		echo "==> Installing to $$dest..."; \
	fi; \
	pkill -x "$(APP_NAME)" 2>/dev/null || true; \
	rm -rf "$$dest/$(APP)"; \
	ditto "$(APP)" "$$dest/$(APP)"; \
	open "$$dest/$(APP)"

## Generate Xcode project via xcodegen (for IDE use)
setup:
	@echo "==> Checking for xcodegen..."
	@command -v xcodegen > /dev/null 2>&1 || brew install xcodegen
	@echo "==> Generating Xcode project..."
	xcodegen generate
	open NextMeeting.xcodeproj

## Remove build artifacts
clean:
	@echo "==> Cleaning..."
	rm -rf "$(APP)"
	@echo "==> Clearing cached update state (UserDefaults)..."
	@defaults delete "$(BUNDLE_ID)" updates.availableVersion 2>/dev/null || true
	@defaults delete "$(BUNDLE_ID)" updates.availableDownloadURL 2>/dev/null || true
	@defaults delete "$(BUNDLE_ID)" updates.lastUpdateCheckDate 2>/dev/null || true
	@echo "Done."
