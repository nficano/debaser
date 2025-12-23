#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-rpm.sh [--target <triple>] [--out-dir <dir>]

Builds an RPM package via cargo-generate-rpm.

Defaults:
  --target   x86_64-unknown-linux-gnu
  --out-dir  dist
EOF
}

target_triple="x86_64-unknown-linux-gnu"
out_dir="dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      target_triple="${2:?missing --target value}"
      shift 2
      ;;
    --out-dir)
      out_dir="${2:?missing --out-dir value}"
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

if ! command -v cargo-generate-rpm >/dev/null 2>&1; then
  echo "cargo-generate-rpm not found; install with: cargo install cargo-generate-rpm --locked" >&2
  exit 1
fi

echo "Building RPM for ${target_triple}..."
cargo build --release --locked --target "${target_triple}"

# cargo-generate-rpm uses the build artifacts; keep this separate so we can pass --target.
cargo generate-rpm --release --target "${target_triple}"

rpm_path="$(find "target/${target_triple}/generate-rpm" -maxdepth 1 -type f -name '*.rpm' | head -n 1 || true)"
if [[ -z "${rpm_path}" ]]; then
  rpm_path="$(find target -type f -path '*/generate-rpm/*.rpm' | head -n 1 || true)"
fi
if [[ -z "${rpm_path}" ]]; then
  echo "No .rpm produced under target/**/generate-rpm" >&2
  exit 1
fi

mkdir -p "${out_dir}"
cp -v "${rpm_path}" "${out_dir}/"
echo "Wrote: ${out_dir}/$(basename "${rpm_path}")"

