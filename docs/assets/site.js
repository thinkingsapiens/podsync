// Shared behaviour for every page on the site.

// Fetches a GitHub API URL through a localStorage cache, so a repeat
// visit within ttlMs doesn't re-hit the API at all (and each caller's
// existing fallback, a stale cache or a plain Releases-page link
// already in the HTML, still applies if this fails outright). Storage
// reads/writes are try/catched: private-browsing modes and some
// extensions throw on localStorage access rather than just no-op.
//
// The request is aborted after 10s so a hung connection can't leave a
// caller (e.g. changelog.html's "Loading releases…" placeholder) stuck
// forever. It falls through to the same stale-cache-or-throw handling
// as any other failure below.
function cachedFetch(url, cacheKey, ttlMs) {
  var cached = null;
  try {
    var raw = localStorage.getItem(cacheKey);
    if (raw) cached = JSON.parse(raw);
  } catch (e) {
    cached = null;
  }

  if (cached && Date.now() - cached.at < ttlMs) {
    return Promise.resolve(cached.data);
  }

  var controller = new AbortController();
  var timeout = setTimeout(function () { controller.abort(); }, 10000);

  return fetch(url, { signal: controller.signal })
    .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
    .finally(function () { clearTimeout(timeout); })
    .then(function (data) {
      try {
        localStorage.setItem(cacheKey, JSON.stringify({ at: Date.now(), data: data }));
      } catch (e) {
        // Storage full, blocked, or unavailable. The fetch itself still
        // succeeded, so the caller gets fresh data either way.
      }
      return data;
    })
    .catch(function (err) {
      // A stale cache is still better than the generic-page fallback.
      if (cached) return cached.data;
      throw err;
    });
}

// Points every download link at the exact asset for its platform/arch
// instead of the generic Releases page, so a visitor never has to guess
// which of the 6 published files (2 macOS archs, Windows, 3 Linux
// formats) is theirs.
//
// latest.json (the file the in-app updater itself reads) can't be used
// for this: its own download URL has no CORS headers, so a page-side
// fetch() of it is silently blocked by the browser, and even its
// platform "url" fields point at api.github.com/.../assets/<id>, which
// returns JSON instead of the file unless the request sends an
// Accept: application/octet-stream header, not something a plain <a
// href> click can do. The public REST API's release-by-tag endpoint
// doesn't have either problem: it's CORS-enabled (verified: responds
// with access-control-allow-origin: *) and hands back each asset's real
// browser_download_url directly. Cached for an hour via cachedFetch
// above, since releases are infrequent and there's no reason to re-hit
// the API on every page load.
(function () {
  var primaryDownload = document.getElementById("primary-download");
  var secondaryLinks = document.querySelectorAll("[data-asset]");
  if (!primaryDownload && secondaryLinks.length === 0) return;

  var ua = navigator.userAgent || "";
  var os = null;
  if (/Windows/i.test(ua)) os = "windows";
  else if (/Mac/i.test(ua)) os = "mac";
  else if (/Linux/i.test(ua) && !/Android/i.test(ua)) os = "linux";

  if (primaryDownload) {
    var label = { windows: "Windows", mac: "Mac", linux: "Linux" }[os];
    primaryDownload.textContent = label ? "Download for " + label : "Download";
  }

  // One matcher per asset kind, run against each release's asset list.
  // Order matters for "dmg": aarch64 must be checked before the plainer
  // "x64" match so PodSync_X_x64.dmg doesn't also match "macAppleSilicon".
  var matchers = {
    macAppleSilicon: function (n) { return /aarch64\.dmg$/.test(n); },
    macIntel: function (n) { return /(?<!aarch64)x64\.dmg$/.test(n); },
    windows: function (n) { return /x64-setup\.exe$/.test(n); },
    linuxAppImage: function (n) { return /\.AppImage$/.test(n); },
    linuxDeb: function (n) { return /\.deb$/.test(n); },
    linuxRpm: function (n) { return /\.rpm$/.test(n); },
  };
  // Which kind the primary button should become for a detected OS. Mac
  // and Linux each have more than one shipped format, so these are just
  // the defaults (newest Apple Silicon Macs, and AppImage since it needs
  // no distro-specific package manager); the secondary links cover the rest.
  var primaryKind = { windows: "windows", mac: "macAppleSilicon", linux: "linuxAppImage" }[os];

  cachedFetch("https://api.github.com/repos/thinkingsapiens/podsync/releases/latest", "podsync_release_latest", 3600000)
    .then(function (release) {
      var assets = release.assets || [];
      function urlFor(kind) {
        var match = matchers[kind]
          ? assets.find(function (a) { return matchers[kind](a.name); })
          : null;
        return match ? match.browser_download_url : null;
      }

      if (primaryDownload && primaryKind) {
        var primaryUrl = urlFor(primaryKind);
        if (primaryUrl) primaryDownload.href = primaryUrl;
      }
      secondaryLinks.forEach(function (link) {
        var url = urlFor(link.dataset.asset);
        if (url) link.href = url;
      });
    })
    .catch(function () {
      // Offline, rate-limited, or the API shape changed: every link
      // already has a working fallback href pointing at the Releases
      // page in the HTML, so there's nothing to fix here, just nothing
      // to improve.
    });
})();

// Renders changelog.html's release list from the public GitHub Releases
// API, the same CORS-enabled, cachedFetch-wrapped endpoint family the
// download-link logic above uses. Previously this page was a static
// shell with RELEASES_START/END sentinel comments, spliced with real
// release data by scripts/build_changelog.py running in CI on every
// push here and again on every release publish on the podsync side
// (see PACKAGING.md's old "Website" section). Reading the API directly
// at page load removes that whole regenerate-and-sync step: the page
// is always current, and there's nothing to keep in sync across two
// repos' workflows.
(function () {
  var container = document.getElementById("releases");
  if (!container) return;

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  function formatDate(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    if (isNaN(d)) return iso;
    return d.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric", timeZone: "UTC" });
  }

  // Minimal Markdown -> HTML for release notes: bold, links, bullet
  // lists, and paragraphs. Covers what `git tag -a -m` notes actually
  // use (see PACKAGING.md), without a Markdown library dependency.
  // Groups by line type rather than blank-line-delimited blocks, since a
  // "**Heading**" line is often immediately followed by "- " items with
  // no blank line in between, as real release notes are written here.
  function renderMarkdown(text) {
    text = escapeHtml(text || "No release notes.");
    text = text.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

    var parts = [];
    var paraLines = [];
    var listItems = [];

    function flushPara() {
      if (paraLines.length) {
        parts.push("<p>" + paraLines.join("<br>") + "</p>");
        paraLines = [];
      }
    }
    function flushList() {
      if (listItems.length) {
        parts.push("<ul>" + listItems.map(function (i) { return "<li>" + i + "</li>"; }).join("") + "</ul>");
        listItems = [];
      }
    }

    text.trim().split("\n").forEach(function (raw) {
      var line = raw.trim();
      if (!line) {
        flushPara();
        flushList();
      } else if (line.indexOf("- ") === 0) {
        flushPara();
        listItems.push(line.slice(2).trim());
      } else if (/^\s/.test(raw) && listItems.length) {
        // Indented continuation of the previous bullet (a `- ` item
        // wrapped onto a second line), not a new paragraph.
        listItems[listItems.length - 1] += " " + line;
      } else {
        flushList();
        paraLines.push(line);
      }
    });
    flushPara();
    flushList();
    return parts.join("\n");
  }

  function renderRelease(r) {
    var name = escapeHtml(r.name || r.tag_name);
    return (
      '<article class="release">' +
        '<div class="release-head">' +
          "<h2>" + name + "</h2>" +
          '<span class="release-date">' + formatDate(r.published_at) + "</span>" +
        "</div>" +
        '<div class="release-body">' + renderMarkdown(r.body) + "</div>" +
        '<p><a href="' + r.html_url + '">View on GitHub &rarr;</a></p>' +
      "</article>"
    );
  }

  cachedFetch("https://api.github.com/repos/thinkingsapiens/podsync/releases?per_page=100", "podsync_releases_all", 3600000)
    .then(function (releases) {
      var shown = releases
        .filter(function (r) { return !r.draft && !r.prerelease; })
        .sort(function (a, b) { return (b.published_at || "") < (a.published_at || "") ? -1 : 1; });
      container.innerHTML = shown.length
        ? shown.map(renderRelease).join("\n")
        : "<p>No releases published yet. Check back soon.</p>";
    })
    .catch(function () {
      container.innerHTML =
        '<p>Couldn\'t load releases right now. See them directly on ' +
        '<a href="https://github.com/thinkingsapiens/podsync/releases">GitHub</a>.</p>';
    });
})();

// Footer copyright year.
var yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = new Date().getFullYear();
}

// One-click copy for command blocks. A button opts in with
// data-copy="<selector of the element holding the text>".
document.querySelectorAll("button[data-copy]").forEach(function (btn) {
  btn.addEventListener("click", async function () {
    var target = document.querySelector(btn.dataset.copy);
    if (!target) return;
    try {
      await navigator.clipboard.writeText(target.textContent.trim());
      btn.textContent = "Copied";
      btn.classList.add("copied");
      setTimeout(function () {
        btn.textContent = "Copy";
        btn.classList.remove("copied");
      }, 1600);
    } catch {
      // Clipboard blocked (not https, or permission denied). The command
      // is still selectable, so leave the button alone rather than lying.
      btn.textContent = "Select it";
      setTimeout(function () {
        btn.textContent = "Copy";
      }, 1600);
    }
  });
});
