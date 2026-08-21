// Shared behaviour for every page on the site.

// Best-effort OS detection for the primary download button's label. Every
// platform link on the page points at the same Releases page regardless —
// this only changes which word the button shows, so a misdetection (or an
// unrecognized OS) just falls back to a neutral label, never a broken link.
var primaryDownload = document.getElementById("primary-download");
if (primaryDownload) {
  var ua = navigator.userAgent || "";
  var platformLabel = null;
  if (/Windows/i.test(ua)) platformLabel = "Windows";
  else if (/Mac/i.test(ua)) platformLabel = "Mac";
  else if (/Linux/i.test(ua) && !/Android/i.test(ua)) platformLabel = "Linux";
  primaryDownload.textContent = platformLabel ? "Download for " + platformLabel : "Download";
}

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
