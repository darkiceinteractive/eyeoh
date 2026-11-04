# EyeOh developer and release entry points. Run `make help` for the list.
#
# Release credentials are never stored here. APP_IDENTITY comes from your shell,
# the notarytool profile is a Keychain item, and the Cloudflare token is read from
# ~/.darkiceconfig/aiconfig.env at deploy time and never printed.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

include version.env

DRY_RUN        ?= 0
NOTARY_PROFILE ?= eyeoh
AI_ENV         ?= $(HOME)/.darkiceconfig/aiconfig.env
CF_PROJECT     := $(shell sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' Website/wrangler.jsonc | head -n 1)
TAG            := v$(MARKETING_VERSION)
DMG_FILE       := dist/EyeOh-$(MARKETING_VERSION)-$(BUILD_NUMBER).dmg
ZIP_FILE       := dist/EyeOh-$(MARKETING_VERSION)-$(BUILD_NUMBER).zip

export NOTARY_PROFILE

.PHONY: help test run check metadata lint site deploy-site bump release mas

help:
	@echo "make test                 swift test"
	@echo "make run                  build and launch the menu-bar app"
	@echo "make check                tests, release metadata, website build, shellcheck"
	@echo "make site                 npm ci and build Website/dist"
	@echo "make deploy-site          deploy Website/dist to Cloudflare Pages ($(CF_PROJECT))"
	@echo "make bump VERSION=x.y.z   bump version files and roll the CHANGELOG (BUILD=n optional)"
	@echo "make release              check, notarize, site, deploy, tag, GitHub release"
	@echo "make release DRY_RUN=1    same, skipping notarize, deploy, tag and GitHub release"
	@echo "make mas                  build the Mac App Store submission package"

test:
	swift test

run:
	./Scripts/compile_and_run.sh

metadata:
	./Scripts/check_release_metadata.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck Scripts/*.sh run-menubar.sh stop-menubar.sh && echo "shellcheck passed."; \
	else \
		echo "warning: shellcheck not installed, skipping shell lint."; \
	fi

site:
	cd Website && npm ci && npm run build

check: test metadata site lint
	@echo "All checks passed."

bump:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make bump VERSION=x.y.z [BUILD=n]" >&2; exit 2; fi
	./Scripts/bump_version.sh "$(VERSION)" $(BUILD)

# Deploys the whole Website/dist in one Pages deployment, so the update archive,
# the DMG and appcast.xml go live together. Authentication: CLOUDFLARE_API_TOKEN
# (or, if absent, CLOUDFLARE_ADMIN_API_TOKEN) from $(AI_ENV); CLOUDFLARE_ACCOUNT_ID
# if set there or in the shell. With neither set, wrangler falls back to its own login.
deploy-site:
	./Scripts/verify_site_artifacts.sh
	python3 Scripts/deploy_site.py --credentials-file "$(AI_ENV)"

mas:
	./Scripts/build_mas_candidate.sh --submission

ifeq ($(DRY_RUN),1)
release:
	@echo "DRY RUN: nothing will be notarized, deployed, tagged or published."
	@if [ -n "$$(/usr/bin/git status --porcelain)" ]; then echo "warning: working tree has uncommitted changes."; fi
	@if /usr/bin/git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null; then echo "warning: tag $(TAG) already exists."; fi
	$(MAKE) check
	@if [ -n "$${APP_IDENTITY:-}" ]; then \
		echo "Building signed (not notarized) candidate without Sentry upload."; \
		env -u SENTRY_DSN -u SENTRY_AUTH_TOKEN ./Scripts/release_direct.sh; \
	else \
		echo "[dry-run] APP_IDENTITY not set, skipping the signed release build."; \
	fi
	./Scripts/verify_site_artifacts.sh --warn
	@echo "[dry-run] would run: ./Scripts/release_direct.sh --notarize (NOTARY_PROFILE=$(NOTARY_PROFILE))"
	@echo "[dry-run] would run: make site, then make deploy-site (Cloudflare Pages project $(CF_PROJECT))"
	@echo "[dry-run] would commit Website/public/updates/appcast.xml if changed, then tag $(TAG)"
	@echo "[dry-run] would run: gh release create $(TAG) $(DMG_FILE) $(ZIP_FILE)"
	@echo "Dry run complete."
else
release:
	@if [ -z "$${APP_IDENTITY:-}" ]; then echo "Set APP_IDENTITY to the Developer ID Application identity." >&2; exit 1; fi
	@if [ -n "$$(/usr/bin/git status --porcelain)" ]; then echo "Working tree is not clean. Commit or stash first." >&2; exit 1; fi
	@if /usr/bin/git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null; then echo "Tag $(TAG) already exists." >&2; exit 1; fi
	$(MAKE) check
	./Scripts/release_direct.sh --notarize
	$(MAKE) site
	$(MAKE) deploy-site
	@if [ -n "$$(/usr/bin/git status --porcelain Website/public/updates/appcast.xml)" ]; then \
		/usr/bin/git add Website/public/updates/appcast.xml; \
		/usr/bin/git commit -m "Publish EyeOh $(MARKETING_VERSION) appcast"; \
	fi
	/usr/bin/git tag -a "$(TAG)" -m "EyeOh $(MARKETING_VERSION)"
	@if /usr/bin/git remote get-url origin >/dev/null 2>&1; then \
		/usr/bin/git push origin "$(TAG)"; \
		./Scripts/changelog_notes.sh "$(MARKETING_VERSION)" > dist/release-notes.md; \
		gh release create "$(TAG)" "$(DMG_FILE)" "$(ZIP_FILE)" --title "EyeOh $(MARKETING_VERSION)" --notes-file dist/release-notes.md --verify-tag; \
	else \
		echo "warning: no 'origin' remote, skipping tag push and GitHub release."; \
	fi
	@echo "Released EyeOh $(MARKETING_VERSION). Push the appcast commit to origin when ready."
endif
