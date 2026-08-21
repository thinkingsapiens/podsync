#!/bin/bash
#
# PodSync installer.
#
#   /bin/bash -c "$(curl -fsSL https://thinkingsapiens.github.io/podsync/install.sh)"
#
# Downloads the latest release for your platform from GitHub and installs
# it: PodSync.app into /Applications on macOS, or the AppImage into
# ~/.local/bin on Linux. Windows isn't handled here: download and run the
# .exe installer from the releases page instead.
#
# Trust model: macOS builds are ad-hoc signed, not notarized, so this script
# strips the quarantine flag after copying on macOS (the same thing the
# Homebrew cask does). That means the only thing vouching for the download
# is TLS to github.com. If you would rather have Homebrew track and verify
# macOS releases for you:
#
#   brew install thinkingsapiens/podsync/podsync-app
#
# Everything is wrapped in main() so a truncated download cannot half-execute.

set -euo pipefail

REPO="thinkingsapiens/podsync"
MANIFEST="https://github.com/${REPO}/releases/latest/download/latest.json"
PODSYNC_TMP=""
PODSYNC_MNT=""
PODSYNC_DMG=""

info()  { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[33mwarning:\033[0m %s\n' "$1" >&2; }
abort() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

main() {
  local version os

  os="$(uname -s)"
  version="${PODSYNC_VERSION:-}"
  if [ -z "$version" ]; then
    info "Looking up the latest release"
    version="$(curl -fsSL "$MANIFEST" \
      | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -1)"
  fi
  [ -n "$version" ] || abort "Could not determine the latest version."

  case "$os" in
    Darwin) install_macos "$version" ;;
    Linux)  install_linux "$version" ;;
    *)      abort "Unsupported OS: ${os}. PodSync supports macOS, Windows, and Linux. On Windows, download the .exe installer from https://github.com/${REPO}/releases/latest instead of running this script." ;;
  esac
}

# --- macOS: download the .dmg for the current architecture, mount it, and
# copy PodSync.app into /Applications (or $PODSYNC_INSTALL_DIR). ---
install_macos() {
  local version="$1"
  local install_dir arch suffix dmg url tmp mnt
  local -r app="PodSync.app"

  install_dir="${PODSYNC_INSTALL_DIR:-/Applications}"

  arch="$(uname -m)"
  case "$arch" in
    arm64)  suffix="aarch64" ;;
    x86_64) suffix="x64" ;;
    *)      abort "Unsupported Mac architecture: ${arch}." ;;
  esac

  if pgrep -f "${app}/Contents/MacOS/podsync" >/dev/null 2>&1; then
    abort "PodSync is running. Quit it first, then re-run this installer."
  fi

  dmg="PodSync_${version}_${suffix}.dmg"
  url="https://github.com/${REPO}/releases/download/v${version}/${dmg}"

  tmp="$(mktemp -d)"
  mnt="${tmp}/mnt"
  PODSYNC_TMP="$tmp"
  PODSYNC_MNT="$mnt"
  PODSYNC_DMG="$dmg"
  trap cleanup EXIT

  info "Downloading PodSync ${version} for macOS (${arch})"
  curl -fL --progress-bar -o "${tmp}/${dmg}" "$url" \
    || abort "Download failed: ${url}"

  verify_checksum "$url" "${tmp}/${dmg}" "$dmg"

  mkdir -p "$mnt"
  hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" "${tmp}/${dmg}" >/dev/null \
    || abort "Could not mount ${dmg}."
  [ -d "${mnt}/${app}" ] || abort "${app} not found inside the disk image."

  if [ ! -d "$install_dir" ]; then
    mkdir -p "$install_dir" || abort "Could not create ${install_dir}."
  fi
  if [ ! -w "$install_dir" ]; then
    abort "${install_dir} is not writable. Re-run with sudo, or set PODSYNC_INSTALL_DIR=\$HOME/Applications"
  fi

  info "Installing to ${install_dir}/${app}"
  retire_existing_macos "${install_dir}/${app}" "$app"
  ditto "${mnt}/${app}" "${install_dir}/${app}" || abort "Copy failed."

  # Ad-hoc signed build: without this, Gatekeeper refuses to launch it.
  xattr -cr "${install_dir}/${app}" 2>/dev/null || true

  info "PodSync ${version} installed. Launch it with: open -a PodSync"
  printf '    To get automatic upgrades instead, use Homebrew:\n'
  printf '    brew install %s/podsync-app\n' "thinkingsapiens/podsync"
}

# --- Linux: download the .AppImage, make it executable, and place it in
# ~/.local/bin/podsync (or $PODSYNC_INSTALL_DIR). No sudo, no package
# manager detection: .AppImage runs the same way on every distro. Prefer
# the .deb/.rpm from the releases page instead if you want it managed by
# your system's package manager. ---
install_linux() {
  local version="$1"
  local install_dir arch appimage url tmp dest

  install_dir="${PODSYNC_INSTALL_DIR:-${HOME}/.local/bin}"

  arch="$(uname -m)"
  case "$arch" in
    x86_64) : ;;
    *)      abort "Unsupported Linux architecture: ${arch}. Only x86_64 builds are published." ;;
  esac

  if pgrep -f "${install_dir}/podsync" >/dev/null 2>&1; then
    abort "PodSync is running. Quit it first, then re-run this installer."
  fi

  appimage="PodSync_${version}_amd64.AppImage"
  url="https://github.com/${REPO}/releases/download/v${version}/${appimage}"
  dest="${install_dir}/podsync"

  tmp="$(mktemp -d)"
  PODSYNC_TMP="$tmp"
  trap cleanup EXIT

  info "Downloading PodSync ${version} for Linux (${arch})"
  curl -fL --progress-bar -o "${tmp}/${appimage}" "$url" \
    || abort "Download failed: ${url}"

  verify_checksum "$url" "${tmp}/${appimage}" "$appimage"

  mkdir -p "$install_dir" || abort "Could not create ${install_dir}."
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -f "$dest"
  fi
  mv "${tmp}/${appimage}" "$dest" || abort "Install failed."
  chmod +x "$dest"

  info "PodSync ${version} installed to ${dest}"
  case ":${PATH}:" in
    *":${install_dir}:"*) printf '    Launch it with: podsync\n' ;;
    *) printf '    %s is not on your PATH. Launch it with: %s\n    Or add it to PATH: export PATH="%s:$PATH"\n' \
         "$install_dir" "$dest" "$install_dir" ;;
  esac
}

# Shared checksum verification. Published alongside each build's asset by
# the release workflow, named "<asset>.sha256". Optional: an older release
# without one still installs, it just isn't checksum-verified.
verify_checksum() {
  local url="$1" file="$2" name="$3"
  local expected actual tmp
  tmp="$(dirname "$file")/sha256"

  if curl -fsSL -o "$tmp" "${url}.sha256" 2>/dev/null; then
    expected="$(awk '{print $1}' "$tmp")"
    actual="$(shasum -a 256 "$file" 2>/dev/null | awk '{print $1}')"
    if [ -z "$actual" ]; then
      actual="$(sha256sum "$file" | awk '{print $1}')"
    fi
    if [ "$expected" != "$actual" ]; then
      abort "Checksum mismatch for ${name}. Expected ${expected}, got ${actual}. Not installing."
    fi
    info "Checksum verified"
  else
    warn "No published checksum for ${name}; relying on TLS alone."
  fi
}

# Replaces an existing macOS install without deleting anything: the old
# bundle is moved to the Trash in a single mv, so a mistake stays
# recoverable from Finder. Only a path that really is an app bundle is
# touched: a stray file or a symlink sitting at that path stops the
# install instead of being swept away.
retire_existing_macos() {
  local app_path="$1" app_name="$2" trash dest stamp

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
    dest="${trash}/${app_name}"
    if [ -e "$dest" ]; then
      dest="${trash}/PodSync ${stamp}.app"
    fi
    mv "$app_path" "$dest" || abort "Could not move the existing ${app_name} to the Trash."
    info "Moved the previous install to the Trash"
  else
    # No usable Trash (running under sudo, say). Rename in place rather than
    # delete, and say so: a leftover folder is cheaper than a bad delete.
    dest="${app_path%.app}-previous-${stamp}.app"
    mv "$app_path" "$dest" || abort "Could not move the existing ${app_name} aside."
    warn "No usable Trash; previous install renamed to ${dest##*/}. Delete it once the new one works."
  fi
}

# Runs on every exit path, so it must never fail and never touch a
# still-mounted disk image. It removes only the files this script creates
# in its temp dir, by name, then rmdirs the directories it made: rmdir
# refuses to remove a non-empty directory, so anything unexpected gets
# reported, not destroyed.
cleanup() {
  local mnt="${PODSYNC_MNT:-}" tmp="${PODSYNC_TMP:-}" dmg="${PODSYNC_DMG:-}"

  if [ -n "$mnt" ] && [ -d "$mnt" ]; then
    hdiutil detach "$mnt" -quiet >/dev/null 2>&1 \
      || hdiutil detach "$mnt" -force -quiet >/dev/null 2>&1 \
      || true
  fi

  if [ -n "$mnt" ] && [ -e "${mnt}/PodSync.app" ]; then
    warn "Disk image is still mounted; leaving ${tmp} in place."
    return 0
  fi

  if [ -z "$tmp" ]; then
    return 0
  fi
  if [ -n "$dmg" ]; then
    rm -f "${tmp}/${dmg}"
  fi
  rm -f "${tmp}"/*.AppImage "${tmp}/sha256"
  if [ -n "$mnt" ]; then
    rmdir "$mnt" 2>/dev/null || true
  fi
  rmdir "$tmp" 2>/dev/null || warn "Left ${tmp} in place; it was not empty."
  return 0
}

main "$@"
