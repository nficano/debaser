#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-deb.sh [--target <triple>] [--out-dir <dir>]

Builds a Debian package via cargo-deb.

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

if ! command -v cargo-deb >/dev/null 2>&1; then
  echo "cargo-deb not found; install with: cargo install cargo-deb --locked" >&2
  exit 1
fi

echo "Building release binary for ${target_triple}..."
cargo build --release --locked --target "${target_triple}"

echo "Building .deb..."
cargo deb --locked --no-build --target "${target_triple}"

deb_path="$(find "target/${target_triple}/debian" -maxdepth 1 -type f -name '*.deb' | head -n 1 || true)"
if [[ -z "${deb_path}" ]]; then
  echo "No .deb produced under target/${target_triple}/debian" >&2
  exit 1
fi

mkdir -p "${out_dir}"
cp -v "${deb_path}" "${out_dir}/"
echo "Wrote: ${out_dir}/$(basename "${deb_path}")"

