<picture style="display: flex; align-items: center; justify-content: center">
  <source srcset="artwork/debaser-dark@2x.png" media="(prefers-color-scheme: dark)">
  <img src="artwork/debaser-light@2x.png" alt="debaser logo" width="100" height="100" style="margin-bottom: 30px; margin-top: 10px">
</picture>


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

## Development

```sh
cargo test
```
