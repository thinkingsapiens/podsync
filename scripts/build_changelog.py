#!/usr/bin/env python3
"""Regenerates docs/changelog.html's release list from a GitHub releases
API dump (see .github/workflows/update-changelog.yml). Splices between the
RELEASES_START/RELEASES_END sentinel comments so the rest of the page
(head, nav, footer) is untouched.
"""
import html
import json
import sys
from datetime import datetime

START = "<!-- RELEASES_START -->"
END = "<!-- RELEASES_END -->"


def format_date(iso: str) -> str:
    try:
        return datetime.strptime(iso[:10], "%Y-%m-%d").strftime("%B %-d, %Y")
    except (ValueError, TypeError):
        return iso or ""


def render_release(release: dict) -> str:
    name = html.escape(release.get("name") or release["tag_name"])
    date = format_date(release.get("published_at") or "")
    body = html.escape(release.get("body") or "No release notes.")
    url = release["html_url"]
    return (
        '      <article class="release">\n'
        '        <div class="release-head">\n'
        f"          <h2>{name}</h2>\n"
        f'          <span class="release-date">{date}</span>\n'
        "        </div>\n"
        f'        <p class="release-body">{body}</p>\n'
        f'        <p><a href="{url}">View on GitHub &rarr;</a></p>\n'
        "      </article>"
    )


def main(releases_path: str, page_path: str) -> None:
    with open(releases_path, encoding="utf-8") as f:
        releases = json.load(f)

    releases = [r for r in releases if not r.get("draft") and not r.get("prerelease")]
    releases.sort(key=lambda r: r.get("published_at") or "", reverse=True)

    body = (
        "\n".join(render_release(r) for r in releases)
        if releases
        else "      <p>No releases published yet — check back soon.</p>"
    )

    with open(page_path, encoding="utf-8") as f:
        page = f.read()

    start = page.index(START) + len(START)
    end = page.index(END)
    new_page = f"{page[:start]}\n{body}\n      {page[end:]}"

    with open(page_path, "w", encoding="utf-8") as f:
        f.write(new_page)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
