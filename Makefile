APP_NAME := DragConvert
BUNDLE   := build/$(APP_NAME).app
LOG      := $(HOME)/Library/Containers/com.dragconvert.app/Data/Library/Logs/dragconvert.log

.PHONY: help build test run bundle universal dmg install sign generate open clean convert log notarize icon

help:
	@echo "make build      Build the SwiftPM package"
	@echo "make test       Run unit tests"
	@echo "make run        Build, bundle, sign, launch"
	@echo "make install    Build and install to /Applications"
	@echo "make log        Show the app's drag/conversion log"
	@echo "make open       Open the Xcode project (needs xcodegen)"
	@echo "make convert file=<path> to=<ext>"
	@echo "make icon       Regenerate the app icon"
	@echo "make universal Build a universal arm64+x86_64 release bundle"
	@echo "make dmg       Build the universal app and a signed DMG"
	@echo "make notarize   Sign + notarize a Developer ID build"
	@echo "make clean      Remove build artefacts"

build:
	swift build

test:
	swift test

bundle: build
	@chmod +x scripts/make-app-bundle.sh
	@./scripts/make-app-bundle.sh

universal:
	@chmod +x scripts/make-app-bundle.sh
	@CONFIG=release UNIVERSAL=1 ./scripts/make-app-bundle.sh

dmg:
	@chmod +x scripts/make-dmg.sh
	@./scripts/make-dmg.sh

run: bundle
	@-pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@sleep 0.3
	open $(BUNDLE)

install: bundle
	@-pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@sleep 0.3
	@rm -rf "/Applications/$(APP_NAME).app"
	@ditto "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@codesign --verify --deep --strict "/Applications/$(APP_NAME).app"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$(APP_NAME).app"
	@mdimport -f "/Applications/$(APP_NAME).app" 2>/dev/null || true
	@touch "/Applications/$(APP_NAME).app"
	@-killall Finder 2>/dev/null || true
	@-killall Dock 2>/dev/null || true
	@-killall iconservicesagent 2>/dev/null || true
	@rm -rf "$(BUNDLE)"
	@echo "Installed /Applications/$(APP_NAME).app"

log:
	@cat "$(LOG)" 2>/dev/null || echo "No log yet — run 'make run' and try a drag."

generate:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen is missing. Install it with: brew install xcodegen"; exit 1; }
	xcodegen generate

open: generate
	open $(APP_NAME).xcodeproj

icon:
	@swift scripts/make-icon.swift
	@rm -rf Config/AppIcon.iconset && mkdir -p Config/AppIcon.iconset
	@for s in 16 32 128 256 512; do \
		sips -z $$s $$s Config/AppIcon-1024.png --out "Config/AppIcon.iconset/icon_$${s}x$${s}.png" >/dev/null; \
		d=$$((s*2)); sips -z $$d $$d Config/AppIcon-1024.png --out "Config/AppIcon.iconset/icon_$${s}x$${s}@2x.png" >/dev/null; \
	done
	@sips -z 1024 1024 Config/AppIcon-1024.png --out Config/AppIcon.iconset/icon_512x512@2x.png >/dev/null
	@iconutil -c icns Config/AppIcon.iconset -o Config/AppIcon.icns
	@rm -rf Config/AppIcon.iconset

notarize:
	@./scripts/notarize.sh

convert:
	@test -n "$(file)" || { echo "usage: make convert file=<path> to=<ext>"; exit 1; }
	@test -n "$(to)" || { echo "usage: make convert file=<path> to=<ext>"; exit 1; }
	swift run $(APP_NAME) --convert "$(file)" --to "$(to)"

clean:
	rm -rf .build build $(APP_NAME).xcodeproj
