#!/bin/zsh
# Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
#
# Usage: assemble-app.sh <executable> <output-dir> <version>
# Wraps a compiled FreeDial executable into <output-dir>/FreeDial.app and signs it ad hoc.
set -eu
here=${0:A:h}
exe=${1:?executable}; out=${2:?output dir}; version=${3:?version}
app=$out/FreeDial.app

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$exe" "$app/Contents/MacOS/FreeDial"
cp "$here/freedial-connect" "$app/Contents/Resources/freedial-connect"
cp "$here/../assets/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
chmod +x "$app/Contents/MacOS/FreeDial" "$app/Contents/Resources/freedial-connect"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FreeDial</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>io.github.freedial</string>
<key>CFBundleName</key><string>FreeDial</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep -s - "$app" 2>/dev/null || echo "warning: ad-hoc signing failed" >&2
