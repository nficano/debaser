#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-apt-repo.sh --repo-dir <dir> --deb <path> [--deb <path> ...] [--codename <name>] [--architectures <list>] [--gpg-key-id <id>] [--no-sign]

Creates a signed APT repository using reprepro.

Required:
  --repo-dir    Output directory for the repo
  --deb         One or more .deb packages to include

Optional:
  --codename    APT distribution codename (default: stable)
  --architectures Space-separated architectures (default: amd64)
  --gpg-key-id  GPG key id/fingerprint to sign Release files (default: default key)
  --no-sign     Skip signing (unsigned repo)
EOF
}

repo_dir=""
codename="stable"
architectures="amd64"
gpg_key_id=""
sign="true"
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
    --no-sign)
      sign="false"
      shift 1
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
SignWith: no
EOF

for deb in "${deb_files[@]}"; do
  echo "Including: ${deb}"
  reprepro -b "${repo_dir}" includedeb "${codename}" "${deb}"
done

reprepro -b "${repo_dir}" export

if [[ "${sign}" == "true" ]]; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "gpg not found; install with: sudo apt-get install -y gnupg" >&2
    exit 1
  fi

  release_file="${repo_dir}/dists/${codename}/Release"
  if [[ ! -f "${release_file}" ]]; then
    echo "Missing Release file at: ${release_file}" >&2
    exit 1
  fi

  gpg_args=(--batch --yes --pinentry-mode loopback)
  if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
    gpg_args+=(--passphrase "${GPG_PASSPHRASE}")
  fi
  if [[ -n "${gpg_key_id}" ]]; then
    gpg_args+=(-u "${gpg_key_id}")
  fi

  gpg "${gpg_args[@]}" --clearsign \
    --output "${repo_dir}/dists/${codename}/InRelease" \
    "${release_file}"

  gpg "${gpg_args[@]}" --armor --detach-sign \
    --output "${repo_dir}/dists/${codename}/Release.gpg" \
    "${release_file}"
fi

echo "APT repo created at: ${repo_dir}"
