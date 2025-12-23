<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="artwork/debaser-light@2x.png" />
    <img src="artwork/debaser-dark@2x.png" alt="Debaser" width="150" height="150" />
  </picture>
</p>
<br />

### Deterministic release name generator.

`debaser` turns a git SHA (or any hex-ish checksum) into a friendly, alliterative
`adjective-noun` release name (for example: `loony-lionfish`).

## Install

From source:

```sh
cargo install --path .
```

## Usage

Inside a git repo, `debaser` uses `git rev-parse HEAD` as the input:

```sh
debaser
```

Or provide an explicit checksum:

```sh
debaser --checksum abcd
# loony-lionfish
```

## Library usage

Add as a dependency (via a path, git, or a published version):

```toml
debaser = { path = "../debaser" }
```

Generate names directly:

```rust
let name = debaser::generate_from_checksum(Some("abcd"))?;
assert_eq!(name, "loony-lionfish");
```

## How it works

- Keeps only hexadecimal characters from the input and uses the first 4 as a seed.
- The first byte selects an adjective; the second selects a noun.
- Nouns are biased to start with the same letter as the adjective.

## Release notes

Releases are cut via the `Makefile` and published as downloadable GitHub Releases (with generated notes and attached binaries).

```sh
make release
```

Requires `debaser` on your `PATH` (run `make install` first).

This will:

- Generate a release tag name by running `debaser`
- Commit any staged/working changes with `Release <tag>` (no-op if there’s nothing to commit)
- Create an annotated git tag and push `main` + the tag to GitHub

## Development

```sh
cargo test
```
