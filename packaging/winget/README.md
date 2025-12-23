# Windows Package Manager (winget)

Winget packages are published by submitting manifests to the community repo:
`microsoft/winget-pkgs`.

After cutting a GitHub Release and generating `SHA256SUMS`, generate manifests:

```sh
scripts/packaging/generate-winget-manifests.sh \
  --version 0.1.0 \
  --sha256sums dist/SHA256SUMS \
  --repo nficano/debaser \
  --output-dir out
```

Then open a PR to `microsoft/winget-pkgs` adding the generated directory:

`out/manifests/n/NickFicano/Debaser/<version>/`

Notes:
- The installer points at the GitHub Release `.zip` asset.
- The zip is treated as a portable install with the `debaser` command alias.

