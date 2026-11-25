#!/bin/zsh
# Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
#
# Build and install FreeDial.app.
#   ./install.sh                 install to ~/Applications
#   ./install.sh --dest DIR      install to DIR (for example /Applications)
set -eu
here=${0:A:h}
dest=$HOME/Applications

while (( $# )); do
  case $1 in
    --dest) dest=${2:?--dest needs a directory}; shift 2 ;;
    -h|--help) sed -n '3,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ $(uname) == Darwin ]] || { echo "FreeDial only runs on macOS." >&2; exit 1 }

if ! command -v swiftc >/dev/null; then
  echo "swiftc not found. Install the Xcode command line tools first:  xcode-select --install" >&2
  exit 1
fi

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

app=$dest/FreeDial.app
mkdir -p "$dest"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

echo "Building..."
swiftc -O "$here/src/main.swift" -o "$app/Contents/MacOS/FreeDial"
cp "$here/scripts/freedial-connect" "$app/Contents/Resources/freedial-connect"
chmod +x "$app/Contents/Resources/freedial-connect"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FreeDial</string>
<key>CFBundleIdentifier</key><string>io.github.freedial</string>
<key>CFBundleName</key><string>FreeDial</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep -s - "$app" 2>/dev/null || echo "warning: ad-hoc signing failed; macOS may ask before opening the app" >&2

echo "Installed $app"
echo "Open it from Finder or Spotlight, or run:  open \"$app\""
