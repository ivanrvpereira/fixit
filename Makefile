APP_NAME := Fixit
DIST_APP := dist/$(APP_NAME).app
INSTALL_APP := /Applications/$(APP_NAME).app
CODE_SIGN_IDENTITY ?= Fixit Local Code Signing

.PHONY: build deploy trust-signing

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

deploy: build
	-osascript -e 'quit app "$(APP_NAME)"' 2>/dev/null
	@sleep 1
	@if command -v trash >/dev/null 2>&1; then trash "$(INSTALL_APP)" 2>/dev/null || true; else rm -rf "$(INSTALL_APP)"; fi
	cp -R "$(DIST_APP)" "$(INSTALL_APP)"
	open "$(INSTALL_APP)"
	@echo "Deployed $(APP_NAME) to $(INSTALL_APP)"
