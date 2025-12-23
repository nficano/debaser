#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: generate-winget-manifests.sh --version <semver> --sha256sums <path> --repo <owner/repo> [--output-dir <dir>]

Generates Windows Package Manager (winget) manifests for a GitHub Release zip.

Example:
  scripts/packaging/generate-winget-manifests.sh \
    --version 0.1.0 \
    --sha256sums dist/SHA256SUMS \
    --repo nficano/debaser \
    --output-dir out
EOF
}

version=""
sha256sums=""
repo=""
output_dir="."

identifier="NickFicano.Debaser"
publisher="Nick Ficano"
package_name="debaser"
package_folder="Debaser"
publisher_folder="NickFicano"
locale="en-US"
manifest_version="1.6.0"

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
    --output-dir)
      output_dir="${2:?missing --output-dir value}"
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
  awk -v f="$filename" '{gsub(/^\\.\\//,"",$2); if ($2==f) {print $1; exit}}' "${sha256sums}"
}

zip_name="debaser-v${version}-x86_64-pc-windows-msvc.zip"
zip_sha="$(sha_for "${zip_name}")"
if [[ -z "${zip_sha}" ]]; then
  echo "Missing checksum in ${sha256sums} for ${zip_name}" >&2
  exit 1
fi

dir_letter="$(printf '%s' "${publisher_folder}" | cut -c1 | tr '[:upper:]' '[:lower:]')"
manifest_dir="${output_dir}/manifests/${dir_letter}/${publisher_folder}/${package_folder}/${version}"
mkdir -p "${manifest_dir}"

base_url="https://github.com/${repo}"
installer_url="${base_url}/releases/download/v${version}/${zip_name}"

cat >"${manifest_dir}/${identifier}.yaml" <<EOF
PackageIdentifier: ${identifier}
PackageVersion: ${version}
DefaultLocale: ${locale}
ManifestType: version
ManifestVersion: ${manifest_version}
EOF

cat >"${manifest_dir}/${identifier}.locale.${locale}.yaml" <<EOF
PackageIdentifier: ${identifier}
PackageVersion: ${version}
PackageLocale: ${locale}
Publisher: ${publisher}
PackageName: ${package_name}
License: Unlicense
ShortDescription: Deterministic release name generator
Moniker: debaser
Tags:
  - cli
  - git
  - naming
  - release
Homepage: ${base_url}
PackageUrl: ${base_url}
LicenseUrl: ${base_url}/blob/main/LICENSE
ReleaseNotesUrl: ${base_url}/releases/tag/v${version}
ManifestType: defaultLocale
ManifestVersion: ${manifest_version}
EOF

cat >"${manifest_dir}/${identifier}.installer.yaml" <<EOF
PackageIdentifier: ${identifier}
PackageVersion: ${version}
InstallerType: zip
NestedInstallerType: portable
NestedInstallerFiles:
  - RelativeFilePath: debaser.exe
    PortableCommandAlias: debaser
Installers:
  - Architecture: x64
    InstallerUrl: ${installer_url}
    InstallerSha256: ${zip_sha}
ManifestType: installer
ManifestVersion: ${manifest_version}
EOF

echo "Wrote: ${manifest_dir}"

