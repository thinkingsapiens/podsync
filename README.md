# podsync

Distribution + website repo for **PodSync**, a lean, native-feeling macOS
podcast client for Apple Silicon. Source lives in a separate private repo —
this one only holds:

- **Releases** — signed `.dmg`/`.app.tar.gz` builds and the `latest.json`
  feed the app's [Tauri updater](https://v2.tauri.app/plugin/updater/)
  checks. Published automatically by the source repo's release workflow
  on each tag push.
- **Website** — [`docs/`](docs/), served via GitHub Pages at
  <https://thinkingsapiens.github.io/podsync/>. `docs/index.html`,
  `docs/docs.html`, `docs/assets/`, `docs/robots.txt`, and
  `docs/sitemap.xml` are authored in the source repo's `website/` and
  synced here automatically by its `website.yml` workflow — don't hand-edit
  them here, edits will be overwritten on the next sync. `docs/changelog.html`
  is the one exception: it regenerates itself from Releases on publish
  (see [`.github/workflows/update-changelog.yml`](.github/workflows/update-changelog.yml)).

Nothing in this repo needs manual editing — both `docs/` and the changelog
are generated/synced automatically.
