#!/bin/zsh
# Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
#
# Install FreeDial.app. By default this downloads the prebuilt release, so no Xcode tools are needed.
#   ./install.sh                  install the latest release to ~/Applications
#   ./install.sh --dest DIR       install to DIR (for example /Applications)
#   ./install.sh --zip FILE       install from a FreeDial.zip you already have
#   ./install.sh --from-source    build from src/ instead (needs the Xcode command line tools)
# It can also be piped from curl; only the default mode works then.
set -eu
here=${0:A:h}
dest=$HOME/Applications
repo=orrdavidm/FreeDial
zip=
from_source=0

while (( $# )); do
  case $1 in
    --dest) dest=${2:?--dest needs a directory}; shift 2 ;;
    --zip) zip=${2:?--zip needs a file}; shift 2 ;;
    --from-source) from_source=1; shift ;;
    -h|--help) sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ $(uname) == Darwin ]] || { echo "FreeDial only runs on macOS." >&2; exit 1 }

# FreeDial drives FreeRDP's SDL client.
PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
if ! command -v sdl-freerdp >/dev/null; then
  echo "FreeDial needs FreeRDP's SDL client (sdl-freerdp), which isn't installed."
  if command -v brew >/dev/null; then
    read -q "reply?Install it now with 'brew install freerdp'? [y/N] " || { echo; echo "Install FreeRDP, then run this again." >&2; exit 1 }
    echo
    brew install freerdp
    command -v sdl-freerdp >/dev/null || { echo "sdl-freerdp is still missing after installing freerdp." >&2; exit 1 }
  else
    echo "Install FreeRDP (for example from https://brew.sh then 'brew install freerdp'), then run this again." >&2
    exit 1
  fi
fi

mkdir -p "$dest"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if (( from_source )); then
  [[ -f $here/src/main.swift ]] || { echo "--from-source needs a checkout of the repository." >&2; exit 1 }
  command -v swiftc >/dev/null || { echo "swiftc not found. Install the Xcode command line tools:  xcode-select --install" >&2; exit 1 }
  echo "Building..."
  swiftc -O "$here/src/main.swift" -o "$work/FreeDial"
  "$here/scripts/assemble-app.sh" "$work/FreeDial" "$work" "$(<"$here/VERSION")"
  rm -rf "$dest/FreeDial.app"
  cp -R "$work/FreeDial.app" "$dest/FreeDial.app"
else
  if [[ -z $zip ]]; then
    base=https://github.com/$repo/releases/latest/download
    echo "Downloading FreeDial..."
    curl -fsSL "$base/FreeDial.zip" -o "$work/FreeDial.zip" || { echo "Couldn't download $base/FreeDial.zip" >&2; exit 1 }
    curl -fsSL "$base/FreeDial.zip.sha256" -o "$work/FreeDial.zip.sha256" || { echo "Couldn't download the checksum file" >&2; exit 1 }
    (cd "$work" && shasum -a 256 -c FreeDial.zip.sha256 >/dev/null) || { echo "Checksum mismatch; not installing." >&2; exit 1 }
    zip=$work/FreeDial.zip
  fi
  ditto -x -k "$zip" "$work/unpacked"
  [[ -d $work/unpacked/FreeDial.app ]] || { echo "That zip doesn't contain FreeDial.app." >&2; exit 1 }
  # A zip saved from a browser is quarantined; the app is ad-hoc signed, so clear that flag.
  xattr -dr com.apple.quarantine "$work/unpacked/FreeDial.app" 2>/dev/null || true
  rm -rf "$dest/FreeDial.app"
  ditto "$work/unpacked/FreeDial.app" "$dest/FreeDial.app"
fi

codesign --verify --deep "$dest/FreeDial.app" 2>/dev/null || echo "warning: signature check failed for $dest/FreeDial.app" >&2
echo "Installed $dest/FreeDial.app"
echo "Open it from Finder or Spotlight, or run:  open \"$dest/FreeDial.app\""
