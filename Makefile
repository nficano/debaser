build:
	cargo build --release --locked

install:
	cargo install --path . --locked

clean:
	cargo clean

BUMP ?= patch
VERSION ?=

release:
	@set -euo pipefail; \
	if [[ -n "$(VERSION)" ]]; then \
		NEW_VERSION="$(VERSION)"; \
		python3 scripts/release/bump-version.py --set "$$NEW_VERSION" >/dev/null; \
	else \
		NEW_VERSION=$$(python3 scripts/release/bump-version.py --bump "$(BUMP)"); \
	fi; \
	cargo generate-lockfile; \
	TAG_NAME="v$$NEW_VERSION"; \
	echo "Generating release name..."; \
	RELEASE_NAME=$$(cargo run --quiet --release --); \
	echo "Version: $$NEW_VERSION"; \
	echo "Tag: $$TAG_NAME"; \
	echo "Release name: $$RELEASE_NAME"; \
	git add -A; \
	git commit -m "Release $$TAG_NAME ($$RELEASE_NAME)" || true; \
	git tag -a "$$TAG_NAME" -m "Release $$TAG_NAME ($$RELEASE_NAME)"; \
	git push origin main; \
	git push origin "$$TAG_NAME"; \
	echo "Released and pushed tag: $$TAG_NAME"
