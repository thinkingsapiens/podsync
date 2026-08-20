#!/bin/bash
#
# PodSync installer.
#
#   /bin/bash -c "$(curl -fsSL https://thinkingsapiens.github.io/podsync/install.sh)"
#
# Downloads the latest release DMG from GitHub and copies PodSync.app into
# /Applications. Homebrew is not required.
#
# Trust model: the app is ad-hoc signed, not notarized, so this script strips
# the quarantine flag after copying (the same thing the Homebrew cask does).
# That means the only thing vouching for the download is TLS to github.com.
# If you would rather have Homebrew track and verify releases for you:
#
#   brew install thinkingsapiens/podsync/podsync-app
#
# Everything is wrapped in main() so a truncated download cannot half-execute.

set -euo pipefail

REPO="thinkingsapiens/podsync"
APP="PodSync.app"
MANIFEST="https://github.com/${REPO}/releases/latest/download/latest.json"
PODSYNC_TMP=""
PODSYNC_MNT=""
PODSYNC_DMG=""

info()  { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[33mwarning:\033[0m %s\n' "$1" >&2; }
abort() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

main() {
  local install_dir version dmg url tmp mnt expected actual

  install_dir="${PODSYNC_INSTALL_DIR:-/Applications}"

  [ "$(uname -s)" = "Darwin" ] || abort "PodSync is macOS only."
  [ "$(uname -m)" = "arm64" ] || abort "PodSync requires Apple Silicon (M1 or newer)."

  if pgrep -f "${APP}/Contents/MacOS/podsync" >/dev/null 2>&1; then
    abort "PodSync is running. Quit it first, then re-run this installer."
  fi

  version="${PODSYNC_VERSION:-}"
  if [ -z "$version" ]; then
    info "Looking up the latest release"
    version="$(curl -fsSL "$MANIFEST" \
      | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -1)"
  fi
  [ -n "$version" ] || abort "Could not determine the latest version."

  dmg="PodSync_${version}_aarch64.dmg"
  url="https://github.com/${REPO}/releases/download/v${version}/${dmg}"

  tmp="$(mktemp -d)"
  mnt="${tmp}/mnt"
  PODSYNC_TMP="$tmp"
  PODSYNC_MNT="$mnt"
  PODSYNC_DMG="$dmg"
  trap cleanup EXIT

  info "Downloading PodSync ${version}"
  curl -fL --progress-bar -o "${tmp}/${dmg}" "$url" \
    || abort "Download failed: ${url}"

  # Published alongside the DMG by the release workflow. Optional: an older
  # release without one still installs, it just isn't checksum-verified.
  if curl -fsSL -o "${tmp}/sha256" "${url}.sha256" 2>/dev/null; then
    expected="$(awk '{print $1}' "${tmp}/sha256")"
    actual="$(shasum -a 256 "${tmp}/${dmg}" | awk '{print $1}')"
    if [ "$expected" != "$actual" ]; then
      abort "Checksum mismatch. Expected ${expected}, got ${actual}. Not installing."
    fi
    info "Checksum verified"
  else
    warn "No published checksum for ${version}; relying on TLS alone."
  fi

  mkdir -p "$mnt"
  hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" "${tmp}/${dmg}" >/dev/null \
    || abort "Could not mount ${dmg}."
  [ -d "${mnt}/${APP}" ] || abort "${APP} not found inside the disk image."

  if [ ! -d "$install_dir" ]; then
    mkdir -p "$install_dir" || abort "Could not create ${install_dir}."
  fi
  if [ ! -w "$install_dir" ]; then
    abort "${install_dir} is not writable. Re-run with sudo, or set PODSYNC_INSTALL_DIR=\$HOME/Applications"
  fi

  info "Installing to ${install_dir}/${APP}"
  retire_existing "${install_dir}/${APP}"
  ditto "${mnt}/${APP}" "${install_dir}/${APP}" || abort "Copy failed."

  # Ad-hoc signed build: without this, Gatekeeper refuses to launch it.
  xattr -cr "${install_dir}/${APP}" 2>/dev/null || true

  info "PodSync ${version} installed. Launch it with: open -a PodSync"
  printf '    To get automatic upgrades instead, use Homebrew:\n'
  printf '    brew install %s/podsync-app\n' "thinkingsapiens/podsync"
}

# Replaces an existing install without deleting anything: the old bundle is
# moved to the Trash in a single mv, so a mistake stays recoverable from
# Finder. Only a path that really is an app bundle is touched — a stray file
# or a symlink sitting at that path stops the install instead of being swept
# away.
retire_existing() {
  local app_path="$1" trash dest stamp

  if [ ! -e "$app_path" ] && [ ! -L "$app_path" ]; then
    return 0
  fi
  if [ -L "$app_path" ]; then
    abort "${app_path} is a symlink, not an app bundle. Remove it yourself, then re-run."
  fi
  if [ ! -d "$app_path" ] || [ ! -f "${app_path}/Contents/Info.plist" ]; then
    abort "${app_path} exists but is not an app bundle. Move it yourself, then re-run."
  fi

  stamp="$(date +%Y-%m-%d-%H%M%S)"
  trash="${HOME:-}/.Trash"

  if [ -n "${HOME:-}" ] && [ -d "$trash" ] && [ -w "$trash" ]; then
    dest="${trash}/${APP}"
    if [ -e "$dest" ]; then
      dest="${trash}/PodSync ${stamp}.app"
    fi
    mv "$app_path" "$dest" || abort "Could not move the existing ${APP} to the Trash."
    info "Moved the previous install to the Trash"
  else
    # No usable Trash (running under sudo, say). Rename in place rather than
    # delete, and say so — a leftover folder is cheaper than a bad delete.
    dest="${app_path%.app}-previous-${stamp}.app"
    mv "$app_path" "$dest" || abort "Could not move the existing ${APP} aside."
    warn "No usable Trash; previous install renamed to ${dest##*/}. Delete it once the new one works."
  fi
}

# Runs on every exit path, so it must never fail and never touch a
# still-mounted disk image. It removes only the two files this script creates,
# by name, then rmdirs the two directories it made: rmdir refuses to remove a
# non-empty directory, so anything unexpected gets reported, not destroyed.
cleanup() {
  local mnt="${PODSYNC_MNT:-}" tmp="${PODSYNC_TMP:-}" dmg="${PODSYNC_DMG:-}"

  if [ -n "$mnt" ] && [ -d "$mnt" ]; then
    hdiutil detach "$mnt" -quiet >/dev/null 2>&1 \
      || hdiutil detach "$mnt" -force -quiet >/dev/null 2>&1 \
      || true
  fi

  if [ -n "$mnt" ] && [ -e "${mnt}/${APP}" ]; then
    warn "Disk image is still mounted; leaving ${tmp} in place."
    return 0
  fi

  if [ -z "$tmp" ]; then
    return 0
  fi
  if [ -n "$dmg" ]; then
    rm -f "${tmp}/${dmg}"
  fi
  rm -f "${tmp}/sha256"
  if [ -n "$mnt" ]; then
    rmdir "$mnt" 2>/dev/null || true
  fi
  rmdir "$tmp" 2>/dev/null || warn "Left ${tmp} in place; it was not empty."
  return 0
}

main "$@"
