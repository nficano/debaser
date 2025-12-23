build:
	cargo build --release

install:
	cargo install --path .

clean:
	cargo clean

release:
	@set -euo pipefail; \
	VERSION=$$(cargo metadata --no-deps --format-version=1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["packages"][0]["version"])'); \
	TAG_NAME="v$$VERSION"; \
	echo "Generating release name..."; \
	RELEASE_NAME=$$(cargo run --quiet --release --); \
	echo "Version: $$VERSION"; \
	echo "Tag: $$TAG_NAME"; \
	echo "Release name: $$RELEASE_NAME"; \
	git add -A; \
	git commit -m "Release $$TAG_NAME ($$RELEASE_NAME)" || true; \
	git tag -a "$$TAG_NAME" -m "Release $$TAG_NAME ($$RELEASE_NAME)"; \
	git push origin main; \
	git push origin "$$TAG_NAME"; \
	echo "Released and pushed tag: $$TAG_NAME"
