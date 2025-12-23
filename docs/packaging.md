# Packaging & distribution

This project is distributed via:

- GitHub Releases (tar.gz / zip + `SHA256SUMS` + signature)
- Debian/Ubuntu: `.deb` + signed APT repo (hosted on `gh-pages`)
- RHEL/Fedora: `.rpm` + signed RPM repo metadata (hosted on `gh-pages`)
- Homebrew: tap formula (generated from `SHA256SUMS`)
- Windows: winget manifests (generated from `SHA256SUMS`)
- Rust: crates.io (`cargo install debaser`)

## Release workflow (GitHub Actions)

`.github/workflows/release.yml` runs on tags `v*` and:

- Builds archives for Linux/macOS/Windows
- Builds `.deb` and `.rpm` on Linux
- Generates `SHA256SUMS` and signs it (`SHA256SUMS.sig`)
- Generates signed APT + RPM repo metadata and publishes them to the `gh-pages` branch:
  - `https://<owner>.github.io/<repo>/apt`
  - `https://<owner>.github.io/<repo>/rpm`
  - `https://<owner>.github.io/<repo>/public.gpg`
- Uploads all artifacts to the GitHub Release

### GitHub Pages setup

The signed APT/RPM repositories are published to the `gh-pages` branch. Enable GitHub Pages for this repo:

1. Repo Settings → Pages
2. Source: Deploy from a branch
3. Branch: `gh-pages` / `root`

## Signing key (local)

Keys and other sensitive release material live outside git in:

`~/Desktop/release-secrets/`

Generated files:

- `public.gpg` (public key; safe to distribute)
- `private.gpg` (private key; never commit)
- `ownertrust.txt`
- `key-fingerprint.txt`
- `gpg-passphrase.txt`

## GitHub Secrets (CI)

Add these repo secrets:

- `GPG_PRIVATE_KEY`: base64 of `~/Desktop/release-secrets/private.gpg`
- `GPG_PASSPHRASE`: contents of `~/Desktop/release-secrets/gpg-passphrase.txt`

Commands (macOS):

```sh
base64 -i ~/Desktop/release-secrets/private.gpg | pbcopy
pbcopy < ~/Desktop/release-secrets/gpg-passphrase.txt
```

## crates.io publishing

Before the first publish, verify metadata:

```sh
cargo package --allow-dirty
cargo publish --dry-run
```

Then publish:

```sh
cargo publish
```

Optional CI automation:

- Add `CRATES_IO_TOKEN` as a GitHub Secret.
- The release workflow will run `cargo publish` on tag `v*`.

## Building packages locally

These are intended to run on Linux hosts.

### Build `.deb`

```sh
cargo install cargo-deb --locked
./scripts/packaging/build-deb.sh --target x86_64-unknown-linux-gnu --out-dir dist
```

Install / uninstall:

```sh
sudo dpkg -i dist/*.deb
sudo dpkg -r debaser
```

### Build `.rpm`

```sh
cargo install cargo-generate-rpm --locked
./scripts/packaging/build-rpm.sh --target x86_64-unknown-linux-gnu --out-dir dist
```

Install / uninstall:

```sh
sudo rpm -ivh dist/*.rpm
sudo rpm -e debaser
```

## Building repositories locally

### APT repo (signed)

Requires `reprepro` + `gnupg`.

```sh
export GPG_PASSPHRASE="$(cat ~/Desktop/release-secrets/gpg-passphrase.txt)"
./scripts/packaging/build-apt-repo.sh \
  --repo-dir dist/apt \
  --codename stable \
  --architectures amd64 \
  --gpg-key-id "$(cat ~/Desktop/release-secrets/key-fingerprint.txt)" \
  --deb dist/*.deb
```

### RPM repo (signed metadata)

Requires `createrepo_c` + `gnupg`.

```sh
export GPG_PASSPHRASE="$(cat ~/Desktop/release-secrets/gpg-passphrase.txt)"
./scripts/packaging/build-rpm-repo.sh \
  --repo-dir dist/rpm \
  --sign \
  --gpg-key-id "$(cat ~/Desktop/release-secrets/key-fingerprint.txt)" \
  --rpm dist/*.rpm
```

## Publishing Homebrew formula

Generate a formula from a released `SHA256SUMS`:

```sh
./scripts/packaging/generate-homebrew-formula.sh \
  --version 0.1.0 \
  --sha256sums dist/SHA256SUMS \
  --repo <owner>/<repo> \
  --output debaser.rb
```

Commit `Formula/debaser.rb` to your tap repository.

## Publishing winget manifests

Generate manifests from a released `SHA256SUMS`:

```sh
./scripts/packaging/generate-winget-manifests.sh \
  --version 0.1.0 \
  --sha256sums dist/SHA256SUMS \
  --repo <owner>/<repo> \
  --output-dir out
```

Open a PR to `microsoft/winget-pkgs` adding the generated `out/manifests/...` directory.

## Key rotation

1. Generate a new signing key in `~/Desktop/release-secrets/` and update the GitHub Secrets.
2. Publish the new `public.gpg` to `gh-pages` (next release does this automatically).
3. In docs, keep the old key available for verifying historical releases.
