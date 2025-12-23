#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-apt-repo.sh --repo-dir <dir> --deb <path> [--deb <path> ...] [--codename <name>] [--architectures <list>] [--gpg-key-id <id>]

Creates a signed APT repository using reprepro.

Required:
  --repo-dir    Output directory for the repo
  --deb         One or more .deb packages to include

Optional:
  --codename    APT distribution codename (default: stable)
  --architectures Space-separated architectures (default: amd64)
  --gpg-key-id  GPG key id/fingerprint to sign Release files (default: default key)
EOF
}

repo_dir=""
codename="stable"
architectures="amd64"
gpg_key_id=""
deb_files=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir)
      repo_dir="${2:?missing --repo-dir value}"
      shift 2
      ;;
    --codename)
      codename="${2:?missing --codename value}"
      shift 2
      ;;
    --architectures)
      architectures="${2:?missing --architectures value}"
      shift 2
      ;;
    --gpg-key-id)
      gpg_key_id="${2:?missing --gpg-key-id value}"
      shift 2
      ;;
    --deb)
      deb_files+=("${2:?missing --deb value}")
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

if [[ -z "${repo_dir}" ]]; then
  echo "--repo-dir is required" >&2
  usage >&2
  exit 2
fi
if [[ ${#deb_files[@]} -eq 0 ]]; then
  echo "At least one --deb is required" >&2
  usage >&2
  exit 2
fi

if ! command -v reprepro >/dev/null 2>&1; then
  echo "reprepro not found; install with: sudo apt-get install -y reprepro" >&2
  exit 1
fi

mkdir -p "${repo_dir}/conf"

cat >"${repo_dir}/conf/distributions" <<EOF
Origin: debaser
Label: debaser
Codename: ${codename}
Suite: ${codename}
Components: main
Architectures: ${architectures}
Description: debaser APT repository
SignWith: ${gpg_key_id:-yes}
EOF

for deb in "${deb_files[@]}"; do
  echo "Including: ${deb}"
  reprepro -b "${repo_dir}" includedeb "${codename}" "${deb}"
done

reprepro -b "${repo_dir}" export

echo "APT repo created at: ${repo_dir}"
