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

### macOS (Homebrew)

Via tap (recommended):

```sh
brew tap nficano/tap
brew install debaser
```

### Debian/Ubuntu (apt)

```sh
curl -fsSL https://nficano.github.io/debaser/public.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/debaser-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/debaser-archive-keyring.gpg] https://nficano.github.io/debaser/apt stable main" | sudo tee /etc/apt/sources.list.d/debaser.list >/dev/null
sudo apt update
sudo apt install debaser
```

### RHEL/Fedora (dnf)

```sh
sudo tee /etc/yum.repos.d/debaser.repo >/dev/null <<'EOF'
[debaser]
name=debaser
baseurl=https://nficano.github.io/debaser/rpm
enabled=1
repo_gpgcheck=1
gpgcheck=0
gpgkey=https://nficano.github.io/debaser/public.gpg
EOF

sudo dnf install debaser
```

### Rust (cargo)

From crates.io (once published):

```sh
cargo install debaser --locked
```

From source:

```sh
cargo install --path .
```

### Manual download (tar.gz / zip)

Download a release asset from GitHub Releases, verify `SHA256SUMS` + `SHA256SUMS.sig`, then extract and place `debaser` on your `PATH`.

### GitHub Actions

Fastest option (uses a prebuilt GitHub Release asset):

```yaml
- name: Install debaser
  shell: bash
  run: |
    set -euo pipefail
    repo="nficano/debaser"
    version="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
    target="x86_64-unknown-linux-gnu"
    asset="debaser-${version}-${target}.tar.gz"
    base="https://github.com/${repo}/releases/download/${version}"
    curl -fsSL "$base/$asset" -o "$asset"
    tar -xzf "$asset"
    sudo install -m 0755 "debaser-${version}-${target}/debaser" /usr/local/bin/debaser
    debaser --checksum abcd
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

Releases are cut via the `Makefile` and published via GitHub Actions (with generated notes and attached binaries / packages / repos).

```sh
make release
```

This tags `v<version>` from `Cargo.toml` and pushes it.

This will:

- Generate a human-friendly release name by running `debaser`
- Commit any staged/working changes with `Release v<version> (<name>)` (no-op if there’s nothing to commit)
- Create an annotated git tag (`v<version>`) and push `main` + the tag to GitHub

## Development

```sh
cargo test
```

## Packaging

See `docs/packaging.md` for full packaging + publishing details.
