# Homebrew (tap)

This repo does not publish to Homebrew core directly. Instead, publish via a tap (recommended):

1. Create a tap repo: `homebrew-tap` (for example: `nficano/homebrew-tap`)
2. Generate a formula from a released `SHA256SUMS` file:

```sh
scripts/packaging/generate-homebrew-formula.sh \
  --version 0.1.0 \
  --sha256sums dist/SHA256SUMS \
  --repo nficano/debaser \
  --output debaser.rb
```

3. Commit `Formula/debaser.rb` to the tap repo and push.

Users can then install via:

```sh
brew tap nficano/tap
brew install debaser
```

