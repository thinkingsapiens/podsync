#!/usr/bin/env python3
"""Regenerates Casks/podsync.rb from podsync's latest published release,
using each release asset's GitHub-computed sha256 digest directly (no need
to download the files just to hash them).

Canonical copy lives here, in thinkingsapiens/gpodder-mac. website.yml
mirrors this and homebrew/podsync.rb.template into
thinkingsapiens/podsync's scripts/ and homebrew/ on every push, where that
repo's update-homebrew-cask.yml runs it whenever a release publishes (see
PACKAGING.md). Edit only here, not in podsync directly.
"""
import json
import sys
import urllib.request

AARCH64_DMG_SUFFIX = "_aarch64.dmg"
X64_DMG_SUFFIX = "_x64.dmg"
AMD64_APPIMAGE_SUFFIX = "_amd64.AppImage"


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


def find_asset(assets: list[dict], suffix: str) -> dict:
    return next(a for a in assets if a["name"].endswith(suffix))


def digest(asset: dict) -> str:
    return asset["digest"].removeprefix("sha256:")


def main(template_path: str, output_path: str, repo: str, token: str) -> None:
    release = fetch_latest_release(repo, token)
    version = release["tag_name"].removeprefix("v")
    assets = release["assets"]

    arm_sha256 = digest(find_asset(assets, AARCH64_DMG_SUFFIX))
    intel_sha256 = digest(find_asset(assets, X64_DMG_SUFFIX))
    linux_sha256 = digest(find_asset(assets, AMD64_APPIMAGE_SUFFIX))

    with open(template_path, encoding="utf-8") as f:
        cask = f.read()

    cask = (
        cask.replace("__VERSION__", version)
        .replace("__SHA256_ARM__", arm_sha256)
        .replace("__SHA256_INTEL__", intel_sha256)
        .replace("__SHA256_LINUX__", linux_sha256)
    )

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(cask)


if __name__ == "__main__":
    main(*sys.argv[1:5])
