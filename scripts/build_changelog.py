#!/usr/bin/env python3
"""Regenerates docs/changelog.html's release list from a GitHub releases
API dump. Splices between the RELEASES_START/RELEASES_END sentinel comments
so the rest of the page (head, nav, footer) is untouched.

Canonical copy lives here, in thinkingsapiens/gpodder-mac. website.yml
mirrors it into thinkingsapiens/podsync's scripts/ on every push, where
that repo's own update-changelog.yml runs it whenever a release publishes
(see PACKAGING.md). Edit only here, not in podsync directly.
"""
import html
import json
import re
import sys
from datetime import datetime

START = "<!-- RELEASES_START -->"
END = "<!-- RELEASES_END -->"


def format_date(iso: str) -> str:
    try:
        return datetime.strptime(iso[:10], "%Y-%m-%d").strftime("%B %-d, %Y")
    except (ValueError, TypeError):
        return iso or ""


def render_markdown(text: str) -> str:
    """Minimal Markdown -> HTML for release notes: bold, links, bullet
    lists, and paragraphs. Covers what `git tag -a -m` notes actually use
    (see PACKAGING.md) without pulling in a Markdown dependency.

    Groups by line type rather than blank-line-delimited blocks, since a
    "**Heading**" line is often immediately followed by "- " items with no
    blank line in between, as in real release notes. Block-splitting would
    otherwise lump the heading into the list's paragraph text."""
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)

    parts: list[str] = []
    para_lines: list[str] = []
    list_items: list[str] = []

    def flush_para() -> None:
        if para_lines:
            parts.append(f"<p>{'<br>'.join(para_lines)}</p>")
            para_lines.clear()

    def flush_list() -> None:
        if list_items:
            items = "".join(f"<li>{item}</li>" for item in list_items)
            parts.append(f"<ul>{items}</ul>")
            list_items.clear()

    for raw_line in text.strip().splitlines():
        line = raw_line.strip()
        if not line:
            flush_para()
            flush_list()
        elif line.startswith("- "):
            flush_para()
            list_items.append(line[2:].strip())
        else:
            flush_list()
            para_lines.append(line)
    flush_para()
    flush_list()
    return "\n        ".join(parts)


def render_release(release: dict) -> str:
    name = html.escape(release.get("name") or release["tag_name"])
    date = format_date(release.get("published_at") or "")
    body = render_markdown(release.get("body") or "No release notes.")
    url = release["html_url"]
    return (
        '      <article class="release">\n'
        '        <div class="release-head">\n'
        f"          <h2>{name}</h2>\n"
        f'          <span class="release-date">{date}</span>\n'
        "        </div>\n"
        f'        <div class="release-body">\n        {body}\n        </div>\n'
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
        else "      <p>No releases published yet. Check back soon.</p>"
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
