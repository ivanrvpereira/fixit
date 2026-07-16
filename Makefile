# Local builds are the "Fixit Dev" variant so they coexist with the
# brew-installed Fixit.app: own bundle id (separate Accessibility grant),
# own config dir, own app in /Applications. Release builds come from CI,
# which calls scripts/build-app.sh with its defaults (Fixit / dev.fixitapp.fixit).
APP_NAME := FixitDev
APP_DISPLAY_NAME := Fixit Dev
BUNDLE_ID := dev.fixitapp.fixit.dev
DEV_CONFIG_DIR := $(HOME)/.config/fixit-dev
DIST_APP := dist/$(APP_NAME).app
INSTALL_APP := /Applications/$(APP_NAME).app
CODE_SIGN_IDENTITY ?= Fixit Local Code Signing

# Swift Testing ships inside Xcode toolchains. With Command Line Tools alone,
# SwiftPM misses the Testing.framework search paths, so pass them explicitly.
DEVELOPER_DIR := $(shell xcode-select -p)
CLT_TESTING_FRAMEWORKS := $(DEVELOPER_DIR)/Library/Developer/Frameworks
CLT_TESTING_RPATH := $(DEVELOPER_DIR)/Library/Developer/usr/lib

.PHONY: build deploy test

build:
	APP_NAME="$(APP_NAME)" APP_DISPLAY_NAME="$(APP_DISPLAY_NAME)" \
	BUNDLE_ID="$(BUNDLE_ID)" APP_CONFIG_DIR="$(DEV_CONFIG_DIR)" \
	CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" ./scripts/build-app.sh

test:
	@if [ -d "$(CLT_TESTING_FRAMEWORKS)/Testing.framework" ]; then \
		swift test \
			-Xswiftc -F -Xswiftc "$(CLT_TESTING_FRAMEWORKS)" \
			-Xlinker -F -Xlinker "$(CLT_TESTING_FRAMEWORKS)" \
			-Xlinker -rpath -Xlinker "$(CLT_TESTING_FRAMEWORKS)" \
			-Xlinker -rpath -Xlinker "$(CLT_TESTING_RPATH)"; \
	else \
		swift test; \
	fi

deploy: build
	-osascript -e 'quit app id "$(BUNDLE_ID)"' 2>/dev/null
	@sleep 1
	@if command -v trash >/dev/null 2>&1; then trash "$(INSTALL_APP)" 2>/dev/null || true; else rm -rf "$(INSTALL_APP)"; fi
	cp -R "$(DIST_APP)" "$(INSTALL_APP)"
	open "$(INSTALL_APP)"
	@echo "Deployed $(APP_NAME) to $(INSTALL_APP)"
