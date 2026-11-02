APP_NAME := DragConvert
BUNDLE   := build/$(APP_NAME).app
LOG      := $(HOME)/Library/Containers/com.dragconvert.app/Data/Library/Logs/dragconvert.log

.PHONY: help build test run bundle sign generate open clean convert log

help:
	@echo "make build      Build the SwiftPM package"
	@echo "make test       Run unit tests"
	@echo "make run        Build, bundle, sign, launch"
	@echo "make log        Show the app's drag/conversion log"
	@echo "make open       Open the Xcode project (needs xcodegen)"
	@echo "make convert file=<path> to=<ext>"
	@echo "make clean      Remove build artefacts"

build:
	swift build

test:
	swift test

bundle: build
	@chmod +x scripts/make-app-bundle.sh
	@./scripts/make-app-bundle.sh

run: bundle
	@-pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@sleep 0.3
	open $(BUNDLE)

log:
	@cat "$(LOG)" 2>/dev/null || echo "No log yet — run 'make run' and try a drag."

generate:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen is missing. Install it with: brew install xcodegen"; exit 1; }
	xcodegen generate

open: generate
	open $(APP_NAME).xcodeproj

convert:
	@test -n "$(file)" || { echo "usage: make convert file=<path> to=<ext>"; exit 1; }
	@test -n "$(to)" || { echo "usage: make convert file=<path> to=<ext>"; exit 1; }
	swift run $(APP_NAME) --convert "$(file)" --to "$(to)"

clean:
	rm -rf .build build $(APP_NAME).xcodeproj
