#!/usr/bin/env python3
"""Regenerates Casks/podsync.rb from podsync's latest published release,
using the release asset's GitHub-computed sha256 digest directly (no need
to download the .dmg just to hash it).

Canonical copy lives here, in thinkingsapiens/gpodder-mac. website.yml
mirrors this and homebrew/podsync.rb.template into
thinkingsapiens/podsync's scripts/ and homebrew/ on every push, where that
repo's update-homebrew-cask.yml runs it whenever a release publishes (see
PACKAGING.md). Edit only here, not in podsync directly.
"""
import json
import sys
import urllib.request

DMG_ASSET_SUFFIX = "_aarch64.dmg"


def fetch_latest_release(repo: str, token: str) -> dict:
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/releases/latest",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def main(template_path: str, output_path: str, repo: str, token: str) -> None:
    release = fetch_latest_release(repo, token)
    version = release["tag_name"].removeprefix("v")

    dmg_asset = next(
        a for a in release["assets"] if a["name"].endswith(DMG_ASSET_SUFFIX)
    )
    sha256 = dmg_asset["digest"].removeprefix("sha256:")

    with open(template_path, encoding="utf-8") as f:
        cask = f.read()

    cask = cask.replace("__VERSION__", version).replace("__SHA256__", sha256)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(cask)


if __name__ == "__main__":
    main(*sys.argv[1:5])
