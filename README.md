<div align="center">

<img src="docs/assets/icon-512.png" alt="PodSync icon" width="120" />

# PodSync

**A lean, native podcast client for macOS, Windows, and Linux.** Offline-first, synced with gpodder.net, ads skipped on-device.

[![Latest release](https://img.shields.io/github/v/release/thinkingsapiens/podsync?include_prereleases&label=release&color=c6ff1a)](https://github.com/thinkingsapiens/podsync/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-Apple%20Silicon%20%C2%B7%20Intel-lightgrey.svg)](https://github.com/thinkingsapiens/podsync/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%2B-0078D6.svg)](https://github.com/thinkingsapiens/podsync/releases/latest)
[![Linux](https://img.shields.io/badge/Linux-x86__64-FCC624.svg)](https://github.com/thinkingsapiens/podsync/releases/latest)
[![Homebrew](https://img.shields.io/badge/homebrew-podsync--app-orange.svg)](https://github.com/thinkingsapiens/homebrew-podsync)

**[Website](https://thinkingsapiens.github.io/podsync/)** · **[Docs](https://thinkingsapiens.github.io/podsync/docs.html)** · **[Changelog](https://thinkingsapiens.github.io/podsync/changelog.html)** · **[Releases](https://github.com/thinkingsapiens/podsync/releases)**

<!-- TODO: swap for a real hero GIF/screenshot once captured; see "Screenshots we need" below -->
*Screenshots and a demo GIF are coming with the next release.*

</div>

## Why PodSync?

- **Nothing leaves your device.**
  - Ad detection and episode transcription run entirely on-device.
  - Nothing goes out except sync data to gpodder.net.
- **Actually offline.**
  - Your library lives in a local SQLite database, not a cache in front of someone else's API.
  - Browse, play, and manage downloads with zero connection.
- **Skips ads without touching your files.**
  - On-device detection finds sponsor reads and skips them during playback.
  - The downloaded episode itself is never re-encoded or cut.
- **Search inside what you've heard.**
  - On-device transcripts make every episode full-text searchable.
  - Click any line in the transcript to jump straight to that moment.
- **See where the ad breaks are.**
  - The episode waveform highlights every detected ad segment right on the timeline.
- **Syncs without locking you in.**
  - Subscriptions and play state sync with gpodder.net, or a self-hosted API-compatible server.
  - Sync is resumable, so a dropped connection or a week offline catches up cleanly.
  - Runs fine alongside other gpodder-protocol clients.
- **Downloads that behave.**
  - Pause, resume, or cancel any download.
  - Storage usage shown is accurate, not estimated.
- **One less menu bar hog.**
  - A native menu-bar mini player keeps controls one click away.
  - Works even with the main window closed.
- **Native, not a browser tab.**
  - Built on Tauri and Rust, not Electron.
  - A small, fast binary with native light/dark appearance.
- **Updates itself.**
  - Releases are signed and self-updating.
  - Check manually from Settings, or just leave it alone.

## Sync compatibility

PodSync speaks the same gpodder sync protocol as everything else in this space, not a proprietary one. Subscriptions and play state sync with:

| Provider | Type |
|---|---|
| [gpodder.net](https://gpodder.net) | Hosted (default) |
| [oPodSync](https://github.com/kd2org/opodsync) | Self-hosted |
| [PinePods](https://github.com/madeofpendletonwool/PinePods) | Self-hosted |
| Nextcloud GPodder Sync | Self-hosted |

It's the same protocol gPodder, AntennaPod, and other gpodder-compatible clients speak, so switching to PodSync doesn't mean losing your subscriptions or listening history. You can run it alongside another client too.

## Install

**macOS**, via Homebrew:

```sh
brew install thinkingsapiens/podsync/podsync-app
```

Or grab the platform installer directly from the [latest release](https://github.com/thinkingsapiens/podsync/releases/latest): a `.dmg` for **macOS** (Apple Silicon or Intel), a `.exe` for **Windows**, or a `.deb`/`.rpm`/`.AppImage` for **Linux**. Full instructions, including a one-line install script for macOS and Linux, are in the [docs](https://thinkingsapiens.github.io/podsync/docs.html#requirements).

**Requirements:** macOS 11 (Big Sur) or later (Apple Silicon or Intel), Windows 10 or later, or a modern 64-bit Linux distribution.

## Quick start

1. Open PodSync. Sign in with your gpodder.net account, a self-hosted gpodder-compatible server, or skip sign-in and add podcasts by URL. Browsing, playback, and downloads all work with no account at all.
2. Subscribe to a podcast, by search or by feed URL.
3. Play. PodSync syncs subscriptions and play state in the background whenever you're online, and picks up right where you left off after any offline stretch.

## Screenshots we need

The hero section above is a placeholder. Real shots to capture and drop into `assets/`:

- Main library view (sidebar + episode list)
- Episode detail view with the waveform and a detected ad segment highlighted
- Transcript view (search + click-to-seek)
- Menu-bar mini player popover
- Settings, light and dark appearance
- One short GIF: add a podcast, play it, and dismiss a "Skipped an ad" toast

## Showcase carousel assets

The "PodSync in action" section on the home page (`index.html`, `.story-showcase`) is a
GSAP scroll-driven carousel. Its images are downscaled WebP copies kept in
`assets/story/`, not the full-res PNGs in `assets/` (all 12 together are ~580 KB, vs
~3 MB at full res).

**Source images.** The app's e2e suite renders 2x screenshots into `tests/e2e/assets/`
in the main repo (see the app `CLAUDE.md`). Those are 2880x1800, i.e. 16:10. Copy the
ones you want to feature into `website/assets/` under their existing names, same as the
other site screenshots.

**Convert for the carousel.** `cwebp` comes from `brew install webp`. From
`website/assets/`, generate a 1600px-wide WebP per screenshot:

```sh
for name in shell transcript settings-dark speed-menu; do
  cwebp -quiet -q 82 -resize 1600 0 "$name.png" -o "story/$name.webp"
done
```

`-resize 1600 0` keeps the aspect ratio (2880x1800 -> 1600x1000). Quality 82 is the
sweet spot; raise it for text-heavy shots that look soft. Keep the original PNG in
`assets/` too, other pages may reference it.

**Wire it into the carousel.** Add one `.story-card` inside `.story-track` in
`index.html` (`data-index` is only for reference; order follows the DOM):

```html
<div class="story-card" data-index="12">
  <img src="docs/assets/story/NAME.webp" alt="..." class="story-image"
       width="1600" height="1000" loading="lazy" decoding="async" />
  <div class="story-overlay">
    <h4>Short label</h4>
    <p>One line describing what's shown</p>
  </div>
</div>
```

No JS or CSS changes are needed: the 16:10 card sizing, the pinned scroll length, the
progress bar, and the mobile / `prefers-reduced-motion` swipe fallback all adapt to the
card count on their own. Every image must be 16:10 or `object-fit: cover` will crop it.

**On a new release.** Capture the new feature in the e2e suite, copy its PNG into
`assets/`, run the `cwebp` line above, and add a `.story-card`. That's the whole loop.

## Links

- [Website](https://thinkingsapiens.github.io/podsync/)
- [Documentation](https://thinkingsapiens.github.io/podsync/docs.html)
- [Changelog](https://thinkingsapiens.github.io/podsync/changelog.html)
- [Homebrew tap](https://github.com/thinkingsapiens/homebrew-podsync)
- [Report an issue](https://github.com/thinkingsapiens/podsync/issues)
