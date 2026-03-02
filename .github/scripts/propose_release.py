#!/usr/bin/env python3
"""
Propose a semver version bump and generate a changelog using Claude.

Uses cargo-semver-checks output as a deterministic baseline,
then layers AI reasoning for changelog generation and validation.
"""

import argparse
import json
import os
import re
import sys
import urllib.request

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
API_URL = "https://api.anthropic.com/v1/messages"

SYSTEM_PROMPT = """\
You are a release engineer for a Rust project. Your job is to analyze changes \
since the last release and produce two things:

1. A semver version bump decision (major, minor, or patch)
2. A user-facing changelog in Markdown

## Semver rules for Rust

- **major**: Removing or renaming public items (structs, functions, traits, \
enum variants, modules). Changing function signatures. Changing type bounds. \
Removing trait implementations. Any change that would cause downstream \
`cargo build` to fail.
- **minor**: Adding new public items. Adding new optional fields behind \
`#[non_exhaustive]`. New trait implementations. New feature flags. New \
optional function parameters with defaults.
- **patch**: Bug fixes. Performance improvements. Internal refactors that \
don't touch the public API. Documentation. Dependency updates (unless they \
change the public API).

## Pre-1.0 semver (0.x.y)

When the major version is 0, the rules shift:
- Breaking changes bump **minor** (not major)
- New features bump **patch**
- Bug fixes bump **patch**

## Inputs you'll receive

- Commit messages since last release
- Code diff (may be truncated)
- cargo-semver-checks report (deterministic breaking change detection)
- Whether cargo-semver-checks flagged breaking changes

## Rules

- If cargo-semver-checks says breaking=true, the bump MUST be at least minor \
(for pre-1.0) or major (for 1.0+). You cannot downgrade this.
- You MAY upgrade the bump if you spot a subtle behavioral break that \
cargo-semver-checks missed.
- Be conservative: when uncertain, choose the higher bump.

## Output format

Respond with ONLY a JSON object (no markdown fences):
{
  "bump": "major|minor|patch",
  "reasoning": "Brief explanation of why this bump level",
  "changelog": "Markdown changelog content with sections: Added, Changed, \
Fixed, Removed (omit empty sections)"
}
"""


def read_file(path: str) -> str:
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""


def bump_version(current_tag: str, bump: str) -> str:
    """Compute new version from current tag and bump type."""
    if not current_tag:
        return "0.1.0"

    version = current_tag.lstrip("v")
    match = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
    if not match:
        return "0.1.0"

    major, minor, patch = (
        int(match.group(1)),
        int(match.group(2)),
        int(match.group(3)),
    )

    if major == 0:
        if bump == "major":
            return f"0.{minor + 1}.0"
        else:
            return f"0.{minor}.{patch + 1}"
    else:
        if bump == "major":
            return f"{major + 1}.0.0"
        elif bump == "minor":
            return f"{major}.{minor + 1}.0"
        else:
            return f"{major}.{minor}.{patch + 1}"


def call_claude(prompt: str) -> dict:
    """Call the Anthropic API and return parsed JSON response."""
    if not ANTHROPIC_API_KEY:
        print("ERROR: ANTHROPIC_API_KEY is not set", file=sys.stderr)
        sys.exit(1)

    payload = json.dumps(
        {
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2000,
            "system": SYSTEM_PROMPT,
            "messages": [{"role": "user", "content": prompt}],
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
        },
    )

    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    text = data["content"][0]["text"]

    # Strip markdown fences if the model included them despite instructions
    text = re.sub(r"^```(?:json)?\s*", "", text.strip())
    text = re.sub(r"\s*```$", "", text.strip())

    return json.loads(text)


def main():
    parser = argparse.ArgumentParser(
        description="Propose a semver bump and changelog using Claude"
    )
    parser.add_argument(
        "--commits", required=True, help="Path to commit messages file"
    )
    parser.add_argument("--diff", required=True, help="Path to code diff file")
    parser.add_argument(
        "--semver-report",
        required=True,
        help="Path to cargo-semver-checks output",
    )
    parser.add_argument(
        "--breaking",
        default="false",
        help="Whether cargo-semver-checks found breaking changes",
    )
    parser.add_argument(
        "--initial",
        default="false",
        help="Whether this is the initial release",
    )
    parser.add_argument(
        "--current-tag", default="", help="Current version tag"
    )
    args = parser.parse_args()

    commits = read_file(args.commits)
    diff = read_file(args.diff)
    semver_report = read_file(args.semver_report)

    if not commits and not diff:
        print(
            "No changes detected since last release. Skipping.",
            file=sys.stderr,
        )
        with open("release-proposal.json", "w") as f:
            json.dump(
                {"bump": "none", "new_version": "", "changelog": ""}, f
            )
        sys.exit(0)

    prompt = f"""\
## Current version
Tag: {args.current_tag or '(none — initial release)'}
Initial release: {args.initial}

## cargo-semver-checks result
Breaking changes detected: {args.breaking}

Report:
{semver_report}

## Commit messages since last release
{commits}

## Code diff (may be truncated)
{diff[:60000]}

Analyze these changes and respond with the JSON object as specified.
"""

    print("Calling Claude for release analysis...", file=sys.stderr)
    result = call_claude(prompt)

    bump = result["bump"]

    # Enforce: AI cannot downgrade past what cargo-semver-checks detected
    if args.breaking == "true" and bump == "patch":
        current_major = 0
        if args.current_tag:
            tag_match = re.match(r"v?(\d+)", args.current_tag)
            if tag_match:
                current_major = int(tag_match.group(1))

        override = "minor" if current_major == 0 else "major"
        print(
            f"WARNING: AI suggested patch but semver-checks found breaking "
            f"changes. Overriding to {override}.",
            file=sys.stderr,
        )
        bump = override
        result["bump"] = bump
        result["reasoning"] += (
            " [OVERRIDDEN: cargo-semver-checks detected breaking changes]"
        )

    new_version = bump_version(args.current_tag, bump)
    result["new_version"] = new_version

    # Write the proposal JSON
    with open("release-proposal.json", "w") as f:
        json.dump(result, f, indent=2)

    # Write the changelog for the PR body
    changelog_md = f"""\
# Release v{new_version}

**Bump:** `{bump}` | **From:** `{args.current_tag or 'initial'}` \u2192 `v{new_version}`

## AI Analysis

> {result.get('reasoning', 'No reasoning provided.')}

## Changelog

{result.get('changelog', 'No changelog generated.')}

---

<details>
<summary>cargo-semver-checks report</summary>

```
{semver_report}
```

</details>

<details>
<summary>Commits included</summary>

{commits}

</details>

> \u26a0\ufe0f Review this proposal before merging. The version bump and changelog \
were generated by AI and validated against cargo-semver-checks.
"""

    with open("release-changelog.md", "w") as f:
        f.write(changelog_md)

    print(
        f"Proposed: {args.current_tag or 'initial'} -> v{new_version} ({bump})",
        file=sys.stderr,
    )
    print(
        f"Reasoning: {result.get('reasoning', 'N/A')}", file=sys.stderr
    )


if __name__ == "__main__":
    main()
