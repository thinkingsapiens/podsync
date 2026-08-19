# podsync

Distribution + website repo for **PodSync**, a lean, native-feeling macOS
podcast client for Apple Silicon. Source lives in a separate private repo —
this one only holds:

- **Releases** — signed `.dmg`/`.app.tar.gz` builds and the `latest.json`
  feed the app's [Tauri updater](https://v2.tauri.app/plugin/updater/)
  checks. Published automatically by the source repo's release workflow
  on each tag push.
- **Website** — [`docs/`](docs/), served via GitHub Pages at
  <https://thinkingsapiens.github.io/podsync/>. `docs/changelog.html`
  regenerates itself from Releases on publish
  (see [`.github/workflows/update-changelog.yml`](.github/workflows/update-changelog.yml)).

Nothing in this repo needs manual editing except `docs/index.html` and
`docs/docs.html` when the app's features or requirements change.
