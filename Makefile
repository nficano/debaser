build:
	cargo build --release

install:
	cargo install --path .

clean:
	cargo clean

release:
	@echo "Generating release name..."
	@TAG_NAME=$$(debaser) && \
	echo "Release name: $$TAG_NAME" && \
	git add -A && \
	git commit -m "Release $$TAG_NAME" || true && \
	git tag -a "$$TAG_NAME" -m "Release $$TAG_NAME" && \
	git push origin main && \
	git push origin "$$TAG_NAME" && \
	echo "Released and pushed tag: $$TAG_NAME"
