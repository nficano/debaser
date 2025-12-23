#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


SEMVER_RE = re.compile(r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)$")


def parse_semver(version: str) -> tuple[int, int, int]:
    match = SEMVER_RE.match(version)
    if not match:
        raise ValueError(f"Invalid semver (expected x.y.z): {version}")
    return int(match["major"]), int(match["minor"]), int(match["patch"])


def bump(version: str, kind: str) -> str:
    major, minor, patch = parse_semver(version)
    if kind == "patch":
        patch += 1
    elif kind == "minor":
        minor += 1
        patch = 0
    elif kind == "major":
        major += 1
        minor = 0
        patch = 0
    else:
        raise ValueError(f"Unknown bump kind: {kind}")
    return f"{major}.{minor}.{patch}"


def read_package_version(cargo_toml: str) -> tuple[str, int]:
    in_package = False
    for idx, line in enumerate(cargo_toml.splitlines()):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_package = stripped == "[package]"
            continue
        if not in_package:
            continue
        match = re.match(r'^version\s*=\s*"(?P<version>[^"]+)"\s*$', stripped)
        if match:
            return match["version"], idx
    raise ValueError("Could not find [package] version in Cargo.toml")


def write_package_version(path: Path, new_version: str) -> None:
    cargo_toml = path.read_text(encoding="utf-8")
    _, version_line_idx = read_package_version(cargo_toml)

    lines = cargo_toml.splitlines(keepends=True)
    lines[version_line_idx] = re.sub(
        r'^(?P<prefix>\s*version\s*=\s*")[^"]+(".*\n?)$',
        rf'\g<prefix>{new_version}\2',
        lines[version_line_idx],
        count=1,
    )
    path.write_text("".join(lines), encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Bump Cargo.toml package version")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--bump", choices=["patch", "minor", "major"])
    group.add_argument("--set", dest="set_version")
    parser.add_argument("--path", default="Cargo.toml")
    args = parser.parse_args(argv)

    path = Path(args.path)
    cargo_toml = path.read_text(encoding="utf-8")
    current, _ = read_package_version(cargo_toml)

    if args.set_version:
        new_version = args.set_version
        parse_semver(new_version)
    else:
        new_version = bump(current, args.bump)

    write_package_version(path, new_version)
    print(new_version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

