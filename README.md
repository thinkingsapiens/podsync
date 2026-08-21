<div align="center">

<img src="docs/assets/icon-512.png" alt="PodSync icon" width="120" />

# PodSync

**A lean, native podcast client for macOS.** Offline-first, synced with gpodder.net, ads skipped on-device.

[![Latest release](https://img.shields.io/github/v/release/thinkingsapiens/podsync?include_prereleases&label=release&color=c6ff1a)](https://github.com/thinkingsapiens/podsync/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%20%C2%B7%20Apple%20Silicon-lightgrey.svg)](https://github.com/thinkingsapiens/podsync/releases/latest)
[![Homebrew](https://img.shields.io/badge/homebrew-podsync--app-orange.svg)](https://github.com/thinkingsapiens/homebrew-podsync)

**[Website](https://thinkingsapiens.github.io/podsync/)** · **[Docs](https://thinkingsapiens.github.io/podsync/docs.html)** · **[Changelog](https://thinkingsapiens.github.io/podsync/changelog.html)** · **[Releases](https://github.com/thinkingsapiens/podsync/releases)**

<!-- TODO: swap for a real hero GIF/screenshot once captured; see "Screenshots we need" below -->
*Screenshots and a demo GIF are coming with the next release.*

</div>

## Why PodSync?

- **Nothing leaves your Mac.** Ad detection and episode transcription run entirely on-device. No audio, no transcript, and no listening history goes anywhere except gpodder.net for sync.
- **Actually offline.** Your library lives in a local SQLite database, not a cache in front of someone else's API. Browse, play, and manage downloads with no connection at all.
- **Skips ads without touching your files.** On-device detection finds sponsor reads and skips them during playback. The downloaded episode itself is never re-encoded or cut.
- **Search inside what you've heard.** On-device transcripts make every episode full-text searchable, with click-to-seek from any line.
- **See where the ad breaks are.** An episode waveform view highlights detected ad segments right on the timeline.
- **Syncs without locking you in.** Subscriptions and play state sync with gpodder.net, or a self-hosted API-compatible server, using resumable sync. Go offline for a week and it catches up cleanly when you're back, and it plays fine alongside other gpodder-protocol clients too.
- **Downloads that behave.** Pause, resume, and cancel, with storage usage that's actually accurate.
- **One less menu bar hog.** A native menu-bar mini player keeps playback controls reachable without the main window open.
- **Native, not a browser tab.** Built on Tauri and Rust: a small, fast binary with native light/dark appearance, not an Electron shell bundling its own browser engine.
- **Updates itself.** Releases are signed and self-updating. Check from Settings, or just leave it alone.

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

```sh
brew install thinkingsapiens/podsync/podsync-app
```

Or download the `.dmg` directly from the [latest release](https://github.com/thinkingsapiens/podsync/releases/latest).

**Requirements:** macOS 11 (Big Sur) or later, Apple Silicon (M1 or newer). Windows and Linux builds are in progress.

## Quick start

1. Open PodSync. Sign in with your gpodder.net account, a self-hosted gpodder-compatible server, or skip sign-in and add podcasts by URL. Browsing, playback, and downloads all work with no account at all.
2. Subscribe to a podcast, by search or by feed URL.
3. Play. PodSync syncs subscriptions and play state in the background whenever you're online, and picks up right where you left off after any offline stretch.

## Screenshots we need

The hero section above is a placeholder. Real shots to capture and drop into `docs/assets/`:

- Main library view (sidebar + episode list)
- Episode detail view with the waveform and a detected ad segment highlighted
- Transcript view (search + click-to-seek)
- Menu-bar mini player popover
- Settings, light and dark appearance
- One short GIF: add a podcast, play it, and dismiss a "Skipped an ad" toast

## Links

- [Website](https://thinkingsapiens.github.io/podsync/)
- [Documentation](https://thinkingsapiens.github.io/podsync/docs.html)
- [Changelog](https://thinkingsapiens.github.io/podsync/changelog.html)
- [Homebrew tap](https://github.com/thinkingsapiens/homebrew-podsync)
- [Report an issue](https://github.com/thinkingsapiens/podsync/issues)
