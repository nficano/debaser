#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: generate-homebrew-formula.sh --version <semver> --sha256sums <path> --repo <owner/repo> [--output <path>]

Generates a Homebrew formula for a GitHub Release tarball based on SHA256SUMS.

Example:
  scripts/packaging/generate-homebrew-formula.sh \
    --version 0.1.0 \
    --sha256sums dist/SHA256SUMS \
    --repo nficano/debaser \
    --output debaser.rb
EOF
}

version=""
sha256sums=""
repo=""
output="debaser.rb"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:?missing --version value}"
      shift 2
      ;;
    --sha256sums)
      sha256sums="${2:?missing --sha256sums value}"
      shift 2
      ;;
    --repo)
      repo="${2:?missing --repo value}"
      shift 2
      ;;
    --output)
      output="${2:?missing --output value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${version}" || -z "${sha256sums}" || -z "${repo}" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "${sha256sums}" ]]; then
  echo "Missing SHA256SUMS file: ${sha256sums}" >&2
  exit 1
fi

sha_for() {
  local filename="$1"
  awk -v f="$filename" '{gsub(/^\.\//,"",$2); if ($2==f) {print $1; exit}}' "${sha256sums}"
}

sha_linux="$(sha_for "debaser-v${version}-x86_64-unknown-linux-gnu.tar.gz")"
sha_macos_intel="$(sha_for "debaser-v${version}-x86_64-apple-darwin.tar.gz")"
sha_macos_arm="$(sha_for "debaser-v${version}-aarch64-apple-darwin.tar.gz")"

if [[ -z "${sha_linux}" || -z "${sha_macos_intel}" || -z "${sha_macos_arm}" ]]; then
  echo "Missing one or more checksums in ${sha256sums} for v${version} tarballs" >&2
  exit 1
fi

cat >"${output}" <<EOF
class Debaser < Formula
  desc "Deterministic release name generator"
  homepage "https://github.com/${repo}"
  version "${version}"
  license "Unlicense"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/${repo}/releases/download/v#{version}/debaser-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "${sha_macos_arm}"
    else
      url "https://github.com/${repo}/releases/download/v#{version}/debaser-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "${sha_macos_intel}"
    end
  end

  on_linux do
    url "https://github.com/${repo}/releases/download/v#{version}/debaser-v#{version}-x86_64-unknown-linux-gnu.tar.gz"
    sha256 "${sha_linux}"
  end

  def install
    target =
      if OS.mac?
        Hardware::CPU.arm? ? "aarch64-apple-darwin" : "x86_64-apple-darwin"
      else
        "x86_64-unknown-linux-gnu"
      end

    bin.install "debaser-v#{version}-#{target}/debaser"
  end

  test do
    assert_match "-", shell_output("#{bin}/debaser --checksum abcd").strip
  end
end
EOF

echo "Wrote: ${output}"
