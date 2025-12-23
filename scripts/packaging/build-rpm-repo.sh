#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-rpm-repo.sh --repo-dir <dir> --rpm <path> [--rpm <path> ...]

Creates a (optionally signed) YUM/DNF repository using createrepo_c.

Required:
  --repo-dir  Output directory for the repo
  --rpm       One or more .rpm packages to include

Optional:
  --sign      Sign repodata/repomd.xml (requires gpg)
EOF
}

repo_dir=""
sign="false"
rpm_files=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir)
      repo_dir="${2:?missing --repo-dir value}"
      shift 2
      ;;
    --rpm)
      rpm_files+=("${2:?missing --rpm value}")
      shift 2
      ;;
    --sign)
      sign="true"
      shift 1
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
if [[ ${#rpm_files[@]} -eq 0 ]]; then
  echo "At least one --rpm is required" >&2
  usage >&2
  exit 2
fi

if ! command -v createrepo_c >/dev/null 2>&1; then
  echo "createrepo_c not found; install with: sudo dnf install -y createrepo_c (or sudo apt-get install -y createrepo-c)" >&2
  exit 1
fi

mkdir -p "${repo_dir}"
for rpm in "${rpm_files[@]}"; do
  cp -v "${rpm}" "${repo_dir}/"
done

createrepo_c "${repo_dir}"

if [[ "${sign}" == "true" ]]; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "gpg not found; install with: sudo dnf install -y gnupg2 (or sudo apt-get install -y gnupg)" >&2
    exit 1
  fi
  gpg --batch --yes --armor --detach-sign \
    --output "${repo_dir}/repodata/repomd.xml.asc" \
    "${repo_dir}/repodata/repomd.xml"
fi

echo "RPM repo created at: ${repo_dir}"

