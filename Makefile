APP_NAME := Fixit
DIST_APP := dist/$(APP_NAME).app
INSTALL_APP := /Applications/$(APP_NAME).app
CODE_SIGN_IDENTITY ?= Fixit Local Code Signing

# Swift Testing ships inside Xcode toolchains. With Command Line Tools alone,
# SwiftPM misses the Testing.framework search paths, so pass them explicitly.
DEVELOPER_DIR := $(shell xcode-select -p)
CLT_TESTING_FRAMEWORKS := $(DEVELOPER_DIR)/Library/Developer/Frameworks
CLT_TESTING_RPATH := $(DEVELOPER_DIR)/Library/Developer/usr/lib

.PHONY: build deploy test trust-signing

# Run once to let codesign use the signing key without password prompts.
trust-signing:
	@security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db | grep -Fq '"$(CODE_SIGN_IDENTITY)"' || { \
		echo 'Missing signing identity: $(CODE_SIGN_IDENTITY)' >&2; \
		echo 'Run ./scripts/create-signing-cert.sh first.' >&2; \
		exit 1; \
	}
	security set-key-partition-list -S apple-tool:,apple:,codesign: -s -t private ~/Library/Keychains/login.keychain-db >/dev/null

build:
	./scripts/build-app.sh

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
	-osascript -e 'quit app "$(APP_NAME)"' 2>/dev/null
	@sleep 1
	@if command -v trash >/dev/null 2>&1; then trash "$(INSTALL_APP)" 2>/dev/null || true; else rm -rf "$(INSTALL_APP)"; fi
	cp -R "$(DIST_APP)" "$(INSTALL_APP)"
	open "$(INSTALL_APP)"
	@echo "Deployed $(APP_NAME) to $(INSTALL_APP)"
